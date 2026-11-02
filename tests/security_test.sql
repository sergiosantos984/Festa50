-- Testes de segurança da base de dados.
-- Correm contra um Postgres com o esquema + seed carregados.
-- Simulam os pedidos do Supabase: SET ROLE anon/authenticated + request.jwt.claims.
\set ON_ERROR_STOP 1
\pset tuples_only on
\pset format unaligned

-- Utilizadores de teste: um admin e um utilizador autenticado SEM permissões de admin.
insert into auth.users (id, email, encrypted_password) values
  ('11111111-1111-1111-1111-111111111111', 'admin@teste.pt', crypt('AntonioTrinca50', gen_salt('bf'))),
  ('22222222-2222-2222-2222-222222222222', 'intruso@teste.pt', crypt('qualquer', gen_salt('bf')))
on conflict do nothing;
insert into public.admins (user_id) values ('11111111-1111-1111-1111-111111111111') on conflict do nothing;

create or replace function pg_temp.expect_fail(sql text, label text) returns text language plpgsql as $$
begin
  execute sql;
  raise exception 'FALHOU (devia ter sido recusado): %', label;
exception when others then
  if sqlerrm like 'FALHOU%' then raise; end if;
  return 'OK  recusado: ' || label || '  [' || sqlstate || ']';
end $$;
grant execute on function pg_temp.expect_fail(text, text) to anon, authenticated;

-- ============ ANÓNIMO (convidado) ============
set role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
select pg_temp.expect_fail('select * from public.clues', 'anon lê tabela clues');
select pg_temp.expect_fail('select * from public.site_documents', 'anon lê site_documents');
select pg_temp.expect_fail('select * from public.location_reveal', 'anon lê location_reveal');
select pg_temp.expect_fail('select * from public.guest_suggestions', 'anon lê sugestões');
select pg_temp.expect_fail('select * from public.admins', 'anon lê admins');
select pg_temp.expect_fail('insert into public.admins values (''22222222-2222-2222-2222-222222222222'')', 'anon promove-se a admin');
select pg_temp.expect_fail('update public.location_reveal set status=''revealed''', 'anon revela localização');
select pg_temp.expect_fail('select public.admin_get_state()', 'anon chama admin_get_state');
select pg_temp.expect_fail('select public.get_preview_site()', 'anon chama get_preview_site');
select pg_temp.expect_fail('select public.admin_set_location_status(''revealed'')', 'anon chama admin_set_location_status');
select pg_temp.expect_fail('select public._audit(''x'',''y'',null)', 'anon chama função interna _audit');

do $$ declare s jsonb := public.get_public_site(); begin
  if jsonb_array_length(s->'clues') <> 0 then raise exception 'FALHOU: pistas em rascunho visíveis ao público'; end if;
  if s->'location'->>'state' <> 'hidden' or s->'location' ? 'venue_name' then raise exception 'FALHOU: localização exposta'; end if;
  if s->'event'->>'date' <> '2026-11-21' then raise exception 'FALHOU: data do evento'; end if;
  if (s->'times'->>'starts_at')::timestamptz <> '2026-11-21 14:30:00+00' then raise exception 'FALHOU: início % ', s->'times'->>'starts_at'; end if;
  if (s->'times'->>'ends_at')::timestamptz <> '2026-11-22 03:00:00+00' then raise exception 'FALHOU: fim (dia seguinte) %', s->'times'->>'ends_at'; end if;
  raise notice 'OK  público: rascunhos privados, localização escondida, 21/11 14:30 -> 22/11 03:00 Lisboa';
end $$;

select public.submit_suggestion('Tio Zé', 'Ana', 'Contador de histórias oficial');
select pg_temp.expect_fail('select public.submit_suggestion(''x'')', 'sugestão com nome curto demais');
select pg_temp.expect_fail('select public.submit_suggestion(repeat(''a'',81))', 'sugestão com nome longo demais');
reset role;

-- ============ AUTENTICADO MAS NÃO ADMIN ============
set role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"22222222-2222-2222-2222-222222222222"}', false);
select pg_temp.expect_fail('select public.admin_get_state()', 'não-admin chama admin_get_state');
select pg_temp.expect_fail('select public.admin_save_document(''event'', ''{}'')', 'não-admin edita evento');
select pg_temp.expect_fail('select public.admin_publish_document(''all'')', 'não-admin publica');
select pg_temp.expect_fail('select public.admin_set_location_status(''revealed'')', 'não-admin revela localização');
select pg_temp.expect_fail('select public.admin_list_suggestions()', 'não-admin lê sugestões');
select pg_temp.expect_fail('select public.get_preview_site()', 'não-admin pré-visualiza');
select pg_temp.expect_fail('insert into public.admins values (''22222222-2222-2222-2222-222222222222'')', 'não-admin promove-se a admin');
do $$ begin
  if (select count(*) from public.clues) <> 0 then raise exception 'FALHOU: não-admin vê pistas'; end if;
exception when insufficient_privilege then raise notice 'OK  recusado: não-admin lê tabela clues [42501]';
end $$;
reset role;

-- conversão de hora (função interna, testada como dono): 16/11 20:00 Lisboa = 20:00 UTC (inverno); julho = UTC+1
do $$ begin
  if public._lisbon('2026-11-16T20:00') <> '2026-11-16 20:00:00+00' then raise exception 'FALHOU: fuso Lisboa inverno'; end if;
  if public._lisbon('2026-07-01T20:00') <> '2026-07-01 19:00:00+00' then raise exception 'FALHOU: fuso Lisboa verão'; end if;
  raise notice 'OK  fuso Europe/Lisbon (inverno e verão)';
end $$;

-- ============ ADMIN ============
set role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}', false);
do $$
declare st jsonb; c1 uuid; c2 uuid; c3 uuid; s jsonb; ev jsonb;
begin
  st := public.admin_get_state();
  if jsonb_array_length(st->'clues') <> 5 then raise exception 'FALHOU: admin não vê as 5 pistas'; end if;
  c1 := (st->'clues'->0->>'id')::uuid; c2 := (st->'clues'->1->>'id')::uuid; c3 := (st->'clues'->2->>'id')::uuid;

  -- publicar uma, agendar outra no futuro, agendar outra e "fazer passar o tempo"
  perform public.admin_set_clue_status(c1, 'published');
  perform public.admin_set_clue_status(c2, 'scheduled', to_char((now() + interval '2 days') at time zone 'Europe/Lisbon', 'YYYY-MM-DD"T"HH24:MI'));
  perform public.admin_set_clue_status(c3, 'scheduled', to_char((now() + interval '1 hour') at time zone 'Europe/Lisbon', 'YYYY-MM-DD"T"HH24:MI'));

  -- agendar no passado é recusado
  begin perform public.admin_set_clue_status(c3, 'scheduled', '2020-01-01T10:00'); raise exception 'FALHOU: agendou no passado';
  exception when sqlstate '22023' then null; end;


  -- localização: não deixa revelar sem link válido / com link não-Google
  begin perform public.admin_set_location_status('revealed'); raise exception 'FALHOU: revelou sem link';
  exception when sqlstate '22023' then null; end;
  begin perform public.admin_save_location('{"venue_name":"X","maps_url":"https://evil.example.com/maps"}');
        raise exception 'FALHOU: aceitou link não-Google';
  exception when sqlstate '22023' then null; end;
  begin perform public.admin_save_location('{"venue_name":"X","maps_url":"javascript:alert(1)"}');
        raise exception 'FALHOU: aceitou javascript:';
  exception when sqlstate '22023' then null; end;
  perform public.admin_save_location('{"venue_name":"Terraço de Teste","venue_address":"Rua de Teste 1, Lisboa","maps_url":"https://maps.app.goo.gl/AbCdEf123","reveal_message":"Até já!"}');
  perform public.admin_set_location_status('scheduled', to_char((now() + interval '3 days') at time zone 'Europe/Lisbon', 'YYYY-MM-DD"T"HH24:MI'));

  -- validação do evento
  ev := public.admin_get_state()->'documents'->'event'->'draft';
  begin perform public.admin_save_document('event', ev || '{"end_date":"2026-11-21"}'); raise exception 'FALHOU: aceitou fim antes do início';
  exception when sqlstate '22023' then null; end;
  begin perform public.admin_save_document('event', ev || '{"whatsapp_number":"12"}'); raise exception 'FALHOU: aceitou WhatsApp inválido';
  exception when sqlstate '22023' then null; end;
  perform public.admin_save_document('event', ev || '{"title":"Rascunho secreto"}');
  raise notice 'OK  admin: estados de pistas, validações, fuso de Lisboa, localização agendada';
end $$;
reset role;

-- ============ O QUE O PÚBLICO VÊ AGORA ============
set role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
do $$ declare s jsonb := public.get_public_site(); begin
  if jsonb_array_length(s->'clues') <> 1 then raise exception 'FALHOU: público devia ver 1 pista, vê %', jsonb_array_length(s->'clues'); end if;
  if jsonb_array_length(s->'upcoming') <> 2 then raise exception 'FALHOU: devia haver 2 pistas futuras'; end if;
  if (s->'upcoming')::text like '%Pista n.º 2%' or (s->'upcoming')::text like '%Lisboa%' then raise exception 'FALHOU: conteúdo de pista futura exposto'; end if;
  if s->'location'->>'state' <> 'scheduled' or (s->'location') ? 'venue_name' or (s->'location') ? 'maps_url' then
    raise exception 'FALHOU: localização agendada expôs dados: %', s->'location'; end if;
  if s->'event'->>'title' = 'Rascunho secreto' then raise exception 'FALHOU: rascunho do evento visível ao público'; end if;
  raise notice 'OK  público: 1 pista publicada, 2 futuras só com data, localização agendada sem dados, rascunho do evento privado';
end $$;
reset role;

-- "Viajar no tempo": pôr as datas agendadas no passado, como se o relógio do servidor tivesse avançado.
update public.clues set publish_at = now() - interval '1 minute' where status = 'scheduled' and publish_at < now() + interval '2 hours';
update public.location_reveal set reveal_at = now() - interval '1 minute' where status = 'scheduled';

set role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
do $$ declare s jsonb := public.get_public_site(); begin
  if jsonb_array_length(s->'clues') <> 2 then raise exception 'FALHOU: pista agendada não ficou visível na hora'; end if;
  if s->'location'->>'state' <> 'revealed' or s->'location'->>'maps_url' <> 'https://maps.app.goo.gl/AbCdEf123' then
    raise exception 'FALHOU: revelação agendada não aconteceu: %', s->'location'; end if;
  raise notice 'OK  público: pista e localização agendadas aparecem quando o relógio do SERVIDOR passa a hora';
end $$;
reset role;

-- Esconder outra vez e publicar documentos
set role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}', false);
select public.admin_set_location_status('hidden') ->> 'status';
select public.admin_discard_draft('event') ->> 'ok';
select count(*) || ' entradas no registo de auditoria' from jsonb_array_elements(public.admin_audit(200));
reset role;

set role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', false);
do $$ declare s jsonb := public.get_public_site(); begin
  if s->'location'->>'state' <> 'hidden' or (s->'location') ? 'venue_name' then raise exception 'FALHOU: voltar a esconder'; end if;
  raise notice 'OK  público: localização volta a ficar escondida';
end $$;
reset role;

-- Auditoria não guarda segredos
do $$ begin
  if exists (select 1 from public.admin_audit_log where details::text ilike '%AntonioTrinca%' or details::text ilike '%password%') then
    raise exception 'FALHOU: segredo no registo de auditoria'; end if;
  raise notice 'OK  auditoria sem passwords; ações: %', (select string_agg(distinct action, ', ') from public.admin_audit_log);
end $$;

select 'TODOS OS TESTES DE SEGURANÇA PASSARAM';
