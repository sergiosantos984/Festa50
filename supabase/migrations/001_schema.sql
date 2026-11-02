-- =====================================================================
--  A FESTA DOS MEUS 50 — esquema da base de dados (Supabase / Postgres)
-- =====================================================================
--  Princípios:
--   * Os convidados (role "anon") NÃO leem nem escrevem tabelas
--     diretamente. Só podem chamar duas funções:
--       - get_public_site()   -> devolve APENAS o conteúdo publicado
--       - submit_suggestion() -> grava uma sugestão (validada)
--   * Todas as escritas administrativas passam por funções admin_*
--     que verificam no servidor se quem chama é administrador
--     (tabela public.admins). Esconder botões no frontend não conta
--     como segurança — isto conta.
--   * Row Level Security ativa em todas as tabelas, como segunda
--     barreira: só administradores podem ler as tabelas.
--   * Publicação agendada é decidida pelo relógio do SERVIDOR (now()),
--     no momento de cada pedido. Não há temporizadores no browser.
--
--  Correr uma vez no SQL Editor do Supabase (ou via supabase db push).
--  É idempotente o suficiente para voltar a correr sem perder dados.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------

create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Documentos do site: 'event' (detalhes do evento) e 'content' (texto
-- de todas as cenas). Cada um tem um rascunho e uma versão publicada.
create table if not exists public.site_documents (
  key              text primary key check (key in ('event', 'content')),
  draft            jsonb not null default '{}'::jsonb,
  published        jsonb,
  draft_updated_at timestamptz not null default now(),
  published_at     timestamptz,
  published_by     uuid
);

create table if not exists public.clues (
  id            uuid primary key default gen_random_uuid(),
  internal_name text not null check (char_length(internal_name) between 1 and 120),
  title         text not null check (char_length(title) between 1 and 160),
  teaser        text not null default '' check (char_length(teaser) <= 300),
  content       text not null default '' check (char_length(content) <= 2000),
  image_url     text not null default '' check (image_url = '' or (image_url ~ '^https://[^\s"''<>]+$' and char_length(image_url) <= 2048)),
  extra_message text not null default '' check (char_length(extra_message) <= 500),
  status        text not null default 'draft' check (status in ('draft', 'scheduled', 'published', 'archived')),
  publish_at    timestamptz,
  published_at  timestamptz,
  sort_order    integer not null default 0,
  style         text not null default 'envelope' check (style in ('envelope', 'postal', 'fosforos', 'polaroid', 'bilhete', 'caderno')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint scheduled_needs_date check (status <> 'scheduled' or publish_at is not null)
);
create index if not exists clues_order_idx on public.clues (sort_order, created_at);

-- Validação do URL do Google Maps (usada pela tabela e pelas funções).
create or replace function public.is_valid_maps_url(u text)
returns boolean language sql immutable as $$
  select u is not null
     and char_length(u) <= 2048
     and u !~ '[\s"''<>\\]'
     and u ~* '^https://((www\.)?google\.(com|pt)/maps([/?].*)?|maps\.google\.(com|pt)/.*|maps\.app\.goo\.gl/[A-Za-z0-9_-]+.*|goo\.gl/maps/[A-Za-z0-9_-]+.*)$';
$$;

create table if not exists public.location_reveal (
  id             smallint primary key default 1 check (id = 1),
  venue_name     text not null default 'Local a revelar' check (char_length(venue_name) between 1 and 120),
  venue_address  text not null default 'Lisboa' check (char_length(venue_address) <= 300),
  maps_url       text not null default '' check (maps_url = '' or public.is_valid_maps_url(maps_url)),
  reveal_message text not null default '' check (char_length(reveal_message) <= 600),
  status         text not null default 'hidden' check (status in ('hidden', 'scheduled', 'revealed')),
  reveal_at      timestamptz,
  revealed_at    timestamptz,
  updated_at     timestamptz not null default now(),
  constraint scheduled_needs_time check (status <> 'scheduled' or reveal_at is not null),
  constraint reveal_needs_url     check (status = 'hidden' or public.is_valid_maps_url(maps_url))
);

create table if not exists public.guest_suggestions (
  id             uuid primary key default gen_random_uuid(),
  suggested_name text not null check (char_length(suggested_name) between 1 and 80),
  suggested_by   text not null default '' check (char_length(suggested_by) <= 60),
  reason         text not null default '' check (char_length(reason) <= 280),
  status         text not null default 'new' check (status in ('new', 'reviewed', 'accepted', 'declined')),
  admin_note     text not null default '' check (char_length(admin_note) <= 1000),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists suggestions_created_idx on public.guest_suggestions (created_at desc);

create table if not exists public.admin_audit_log (
  id          bigserial primary key,
  at          timestamptz not null default now(),
  actor       uuid,
  actor_email text,
  action      text not null,
  entity      text not null,
  entity_id   text,
  details     jsonb not null default '{}'::jsonb
);
create index if not exists audit_at_idx on public.admin_audit_log (at desc);

-- ---------------------------------------------------------------------
-- Permissões: fechar tudo, abrir só o necessário
-- ---------------------------------------------------------------------

alter table public.admins            enable row level security;
alter table public.site_documents    enable row level security;
alter table public.clues             enable row level security;
alter table public.location_reveal   enable row level security;
alter table public.guest_suggestions enable row level security;
alter table public.admin_audit_log   enable row level security;

revoke all on public.admins, public.site_documents, public.clues, public.location_reveal,
              public.guest_suggestions, public.admin_audit_log from anon, authenticated, public;
revoke all on sequence public.admin_audit_log_id_seq from anon, authenticated, public;

-- O service_role (só existe no servidor / scripts) mantém acesso total.
grant all on public.admins, public.site_documents, public.clues, public.location_reveal,
             public.guest_suggestions, public.admin_audit_log to service_role;
grant usage on sequence public.admin_audit_log_id_seq to service_role;

-- is_admin(): verdadeiro só se o utilizador autenticado estiver em public.admins.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- Segunda barreira: mesmo que alguém volte a dar GRANT por engano, só
-- administradores leem; ninguém escreve diretamente (só via funções).
drop policy if exists admin_read on public.site_documents;
drop policy if exists admin_read on public.clues;
drop policy if exists admin_read on public.location_reveal;
drop policy if exists admin_read on public.guest_suggestions;
drop policy if exists admin_read on public.admin_audit_log;
drop policy if exists self_read  on public.admins;
create policy admin_read on public.site_documents    for select to authenticated using (public.is_admin());
create policy admin_read on public.clues             for select to authenticated using (public.is_admin());
create policy admin_read on public.location_reveal   for select to authenticated using (public.is_admin());
create policy admin_read on public.guest_suggestions for select to authenticated using (public.is_admin());
create policy admin_read on public.admin_audit_log   for select to authenticated using (public.is_admin());
create policy self_read  on public.admins            for select to authenticated using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Funções auxiliares (privadas)
-- ---------------------------------------------------------------------

create or replace function public._require_admin()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Sem permissão.' using errcode = '42501';
  end if;
end $$;

create or replace function public._audit(p_action text, p_entity text, p_entity_id text, p_details jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.admin_audit_log (actor, actor_email, action, entity, entity_id, details)
  values (auth.uid(), (select email from auth.users where id = auth.uid()), p_action, p_entity, p_entity_id, coalesce(p_details, '{}'::jsonb));
end $$;

create or replace function public._txt(d jsonb, k text, maxlen int, required boolean default false)
returns text language plpgsql immutable as $$
declare v text;
begin
  if d ? k and jsonb_typeof(d -> k) not in ('string', 'null') then
    raise exception 'O campo "%" tem de ser texto.', k using errcode = '22023';
  end if;
  v := coalesce(btrim(d ->> k), '');
  if required and v = '' then
    raise exception 'O campo "%" é obrigatório.', k using errcode = '22023';
  end if;
  if char_length(v) > maxlen then
    raise exception 'O campo "%" excede % caracteres.', k, maxlen using errcode = '22023';
  end if;
  return v;
end $$;

-- Valida e normaliza o documento de detalhes do evento.
create or replace function public._clean_event(d jsonb)
returns jsonb language plpgsql stable as $$
declare
  r jsonb := '{}'::jsonb;
  tz text; v_date date; v_end date; st time; et time; cap int; wa text; mode text;
begin
  if d is null or jsonb_typeof(d) <> 'object' then
    raise exception 'Documento inválido.' using errcode = '22023';
  end if;
  r := jsonb_build_object(
    'title',               public._txt(d, 'title', 120, true),
    'headline',            public._txt(d, 'headline', 60, true),
    'subtitle',            public._txt(d, 'subtitle', 120),
    'intro_message',       public._txt(d, 'intro_message', 400),
    'final_message',       public._txt(d, 'final_message', 400),
    'description',         public._txt(d, 'description', 1000),
    'city',                public._txt(d, 'city', 80, true),
    'capacity_description',public._txt(d, 'capacity_description', 200),
    'capacity_message',    public._txt(d, 'capacity_message', 200),
    'rsvp_message',        public._txt(d, 'rsvp_message', 600, true),
    'suggestion_message',  public._txt(d, 'suggestion_message', 600, true),
    'rsvp_deadline_text',  public._txt(d, 'rsvp_deadline_text', 160)
  );

  begin
    v_date := (d ->> 'date')::date;  v_end := (d ->> 'end_date')::date;
    st := (d ->> 'start_time')::time; et := (d ->> 'end_time')::time;
  exception when others then
    raise exception 'Data ou hora inválida.' using errcode = '22023';
  end;
  if v_date is null or v_end is null or st is null or et is null then
    raise exception 'Data e horas são obrigatórias.' using errcode = '22023';
  end if;

  tz := coalesce(d ->> 'timezone', 'Europe/Lisbon');
  if not exists (select 1 from pg_timezone_names where name = tz) then
    raise exception 'Fuso horário desconhecido: %', tz using errcode = '22023';
  end if;
  if (v_end + et) <= (v_date + st) then
    raise exception 'O fim tem de ser depois do início (se acaba depois da meia-noite, a data de fim é o dia seguinte).' using errcode = '22023';
  end if;

  begin cap := (d ->> 'capacity')::int; exception when others then cap := null; end;
  if cap is null or cap < 1 or cap > 5000 then
    raise exception 'Capacidade inválida.' using errcode = '22023';
  end if;

  wa := regexp_replace(coalesce(d ->> 'whatsapp_number', ''), '[^0-9]', '', 'g');
  if char_length(wa) < 8 or char_length(wa) > 15 then
    raise exception 'Número de WhatsApp inválido (usa o indicativo, ex.: 351936266342).' using errcode = '22023';
  end if;

  mode := coalesce(d ->> 'suggestions_mode', 'backend');
  if mode not in ('backend', 'whatsapp', 'off') then
    raise exception 'Modo de sugestões inválido.' using errcode = '22023';
  end if;

  return r || jsonb_build_object(
    'date', to_char(v_date, 'YYYY-MM-DD'), 'end_date', to_char(v_end, 'YYYY-MM-DD'),
    'start_time', to_char(st, 'HH24:MI'), 'end_time', to_char(et, 'HH24:MI'),
    'timezone', tz, 'capacity', cap, 'whatsapp_number', wa, 'suggestions_mode', mode);
end $$;

-- O documento de conteúdo é texto livre estruturado; limitamos tipo e tamanho.
-- (O site público escreve sempre texto com textContent, nunca HTML.)
create or replace function public._clean_content(d jsonb)
returns jsonb language plpgsql immutable as $$
begin
  if d is null or jsonb_typeof(d) <> 'object' then
    raise exception 'Documento inválido.' using errcode = '22023';
  end if;
  if octet_length(d::text) > 100000 then
    raise exception 'Conteúdo demasiado grande.' using errcode = '22023';
  end if;
  return d;
end $$;

-- Hora local de Lisboa (ex.: '2026-11-16T20:00') -> timestamptz.
create or replace function public._lisbon(p_local text)
returns timestamptz language plpgsql stable as $$
begin
  if p_local is null or btrim(p_local) = '' then return null; end if;
  return (p_local::timestamp) at time zone 'Europe/Lisbon';
exception when others then
  raise exception 'Data/hora inválida: %', p_local using errcode = '22023';
end $$;

create or replace function public._clue_json(c public.clues)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', c.id, 'internal_name', c.internal_name, 'title', c.title, 'teaser', c.teaser,
    'content', c.content, 'image_url', c.image_url, 'extra_message', c.extra_message,
    'status', c.status, 'publish_at', c.publish_at, 'published_at', c.published_at,
    'sort_order', c.sort_order, 'style', c.style, 'created_at', c.created_at, 'updated_at', c.updated_at,
    'effective_status', case when c.status = 'scheduled' and c.publish_at <= now() then 'published' else c.status end);
$$;

-- Vê se uma pista está visível para o público AGORA (relógio do servidor).
create or replace function public._clue_visible(c public.clues)
returns boolean language sql stable as $$
  select c.status = 'published' or (c.status = 'scheduled' and c.publish_at <= now());
$$;

create or replace function public._location_public()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare l public.location_reveal;
begin
  select * into l from public.location_reveal where id = 1;
  if not found then
    return jsonb_build_object('state', 'hidden');
  end if;
  if (l.status = 'revealed' or (l.status = 'scheduled' and l.reveal_at <= now()))
     and public.is_valid_maps_url(l.maps_url) then
    return jsonb_build_object('state', 'revealed', 'venue_name', l.venue_name, 'venue_address', l.venue_address,
      'maps_url', l.maps_url, 'reveal_message', l.reveal_message,
      'revealed_at', coalesce(l.revealed_at, l.reveal_at));
  elsif l.status = 'scheduled' then
    -- Só a hora prevista: nome, morada e link continuam no servidor.
    return jsonb_build_object('state', 'scheduled', 'reveal_at', l.reveal_at);
  end if;
  return jsonb_build_object('state', 'hidden');
end $$;

create or replace function public._event_times(e jsonb)
returns jsonb language plpgsql stable as $$
declare tz text := coalesce(e ->> 'timezone', 'Europe/Lisbon');
begin
  return jsonb_build_object(
    'starts_at', (((e ->> 'date') || ' ' || (e ->> 'start_time'))::timestamp at time zone tz),
    'ends_at',   (((e ->> 'end_date') || ' ' || (e ->> 'end_time'))::timestamp at time zone tz));
exception when others then
  return '{}'::jsonb;
end $$;

-- ---------------------------------------------------------------------
-- FUNÇÕES PÚBLICAS (anon)
-- ---------------------------------------------------------------------

-- Tudo o que um convidado pode ver, numa chamada.
create or replace function public.get_public_site()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ev jsonb; ct jsonb; ev_at timestamptz;
begin
  select published, published_at into ev, ev_at from public.site_documents where key = 'event';
  select published into ct from public.site_documents where key = 'content';
  return jsonb_build_object(
    'server_time', now(),
    'published_at', ev_at,
    'event', ev,
    'times', case when ev is null then '{}'::jsonb else public._event_times(ev) end,
    'content', ct,
    'clues', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'title', c.title, 'teaser', c.teaser, 'content', c.content,
               'image_url', c.image_url, 'extra_message', c.extra_message, 'style', c.style,
               'available_at', coalesce(c.publish_at, c.published_at, c.created_at))
             order by c.sort_order, c.created_at)
      from public.clues c where public._clue_visible(c)), '[]'::jsonb),
    -- Pistas futuras: só a posição e a data. O conteúdo nunca sai daqui antes da hora.
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object('slot', c.sort_order, 'available_at', c.publish_at, 'style', c.style)
             order by c.publish_at)
      from public.clues c where c.status = 'scheduled' and c.publish_at > now()), '[]'::jsonb),
    'location', public._location_public()
  );
end $$;

-- Sugestão de convidado. Valida, limpa e trava abusos simples.
create or replace function public.submit_suggestion(p_name text, p_by text default '', p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare mode text; n text; b text; r text;
begin
  select coalesce(published ->> 'suggestions_mode', 'backend') into mode from public.site_documents where key = 'event';
  if coalesce(mode, 'backend') <> 'backend' then
    raise exception 'As sugestões não estão abertas por este canal.' using errcode = '42501';
  end if;

  n := btrim(regexp_replace(coalesce(p_name, ''),   '[[:cntrl:]<>]', '', 'g'));
  b := btrim(regexp_replace(coalesce(p_by, ''),     '[[:cntrl:]<>]', '', 'g'));
  r := btrim(regexp_replace(coalesce(p_reason, ''), '[[:cntrl:]<>]', '', 'g'));
  if char_length(n) < 2 or char_length(n) > 80 then
    raise exception 'Escreve um nome entre 2 e 80 caracteres.' using errcode = '22023';
  end if;
  if char_length(b) > 60 or char_length(r) > 280 then
    raise exception 'Texto demasiado longo.' using errcode = '22023';
  end if;

  -- Travão anti-abuso global (não há IP no Postgres): máx. 20 por 10 minutos e 500 no total.
  if (select count(*) from public.guest_suggestions where created_at > now() - interval '10 minutes') >= 20
     or (select count(*) from public.guest_suggestions) >= 500 then
    raise exception 'Muitas sugestões de uma vez. Tenta mais tarde.' using errcode = '54000';
  end if;

  insert into public.guest_suggestions (suggested_name, suggested_by, reason) values (n, b, r);
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- FUNÇÕES DE ADMINISTRAÇÃO (só authenticated + is_admin())
-- ---------------------------------------------------------------------

create or replace function public.admin_whoami()
returns jsonb language plpgsql stable security definer set search_path = public, auth as $$
begin
  return jsonb_build_object('user_id', auth.uid(), 'is_admin', public.is_admin(),
    'email', (select email from auth.users where id = auth.uid()));
end $$;

create or replace function public.admin_get_state()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin();
  return jsonb_build_object(
    'server_time', now(),
    'documents', (select jsonb_object_agg(key, jsonb_build_object(
        'draft', draft, 'published', published, 'draft_updated_at', draft_updated_at,
        'published_at', published_at, 'has_unpublished', (published is distinct from draft)))
      from public.site_documents),
    'clues', coalesce((select jsonb_agg(public._clue_json(c) order by c.sort_order, c.created_at) from public.clues c), '[]'::jsonb),
    'location', (select to_jsonb(l) || jsonb_build_object('public', public._location_public()) from public.location_reveal l where id = 1),
    'suggestions', jsonb_build_object(
        'total', (select count(*) from public.guest_suggestions),
        'new',   (select count(*) from public.guest_suggestions where status = 'new'))
  );
end $$;

create or replace function public.admin_save_document(p_key text, p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare cleaned jsonb;
begin
  perform public._require_admin();
  if p_key = 'event' then cleaned := public._clean_event(p_draft);
  elsif p_key = 'content' then cleaned := public._clean_content(p_draft);
  else raise exception 'Documento desconhecido.' using errcode = '22023';
  end if;
  update public.site_documents set draft = cleaned, draft_updated_at = now() where key = p_key;
  perform public._audit('rascunho_guardado', p_key, p_key, '{}'::jsonb);
  return jsonb_build_object('ok', true, 'draft', cleaned);
end $$;

-- Publica o rascunho de um documento (ou ambos com p_key = 'all').
create or replace function public.admin_publish_document(p_key text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare d record;
begin
  perform public._require_admin();
  if p_key not in ('event', 'content', 'all') then
    raise exception 'Documento desconhecido.' using errcode = '22023';
  end if;
  for d in select * from public.site_documents where p_key = 'all' or key = p_key loop
    -- Revalida no momento de publicar.
    if d.key = 'event' then perform public._clean_event(d.draft); else perform public._clean_content(d.draft); end if;
    update public.site_documents set published = draft, published_at = now(), published_by = auth.uid() where key = d.key;
    perform public._audit('publicado', d.key, d.key, '{}'::jsonb);
  end loop;
  return jsonb_build_object('ok', true, 'published_at', now());
end $$;

create or replace function public.admin_discard_draft(p_key text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._require_admin();
  update public.site_documents set draft = coalesce(published, draft), draft_updated_at = now() where key = p_key;
  perform public._audit('rascunho_descartado', p_key, p_key, '{}'::jsonb);
  return jsonb_build_object('ok', true);
end $$;

-- Cria ou atualiza uma pista (sem mexer no estado — isso é admin_set_clue_status).
create or replace function public.admin_upsert_clue(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare c public.clues; v_id uuid; v_style text; v_img text;
begin
  perform public._require_admin();
  v_style := coalesce(nullif(p ->> 'style', ''), 'envelope');
  v_img := public._txt(p, 'image_url', 2048);
  if v_img <> '' and v_img !~ '^https://[^\s"''<>]+$' then
    raise exception 'A imagem tem de ser um endereço https://' using errcode = '22023';
  end if;
  v_id := nullif(p ->> 'id', '')::uuid;
  if v_id is null then
    insert into public.clues (internal_name, title, teaser, content, image_url, extra_message, style, sort_order)
    values (public._txt(p, 'internal_name', 120, true), public._txt(p, 'title', 160, true),
            public._txt(p, 'teaser', 300), public._txt(p, 'content', 2000), v_img,
            public._txt(p, 'extra_message', 500), v_style,
            coalesce((select max(sort_order) + 1 from public.clues), 1))
    returning * into c;
    perform public._audit('pista_criada', 'clue', c.id::text, jsonb_build_object('nome', c.internal_name));
  else
    update public.clues set
      internal_name = public._txt(p, 'internal_name', 120, true), title = public._txt(p, 'title', 160, true),
      teaser = public._txt(p, 'teaser', 300), content = public._txt(p, 'content', 2000), image_url = v_img,
      extra_message = public._txt(p, 'extra_message', 500), style = v_style, updated_at = now()
    where id = v_id returning * into c;
    if not found then raise exception 'Pista não encontrada.' using errcode = 'P0002'; end if;
    perform public._audit('pista_editada', 'clue', c.id::text, jsonb_build_object('nome', c.internal_name));
  end if;
  return public._clue_json(c);
end $$;

-- Muda o estado: draft | scheduled (com p_publish_at em hora de Lisboa) | published | archived
create or replace function public.admin_set_clue_status(p_id uuid, p_status text, p_publish_at_local text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare c public.clues; v_at timestamptz;
begin
  perform public._require_admin();
  if p_status not in ('draft', 'scheduled', 'published', 'archived') then
    raise exception 'Estado inválido.' using errcode = '22023';
  end if;
  if p_status = 'scheduled' then
    v_at := public._lisbon(p_publish_at_local);
    if v_at is null then raise exception 'Indica a data e hora de publicação.' using errcode = '22023'; end if;
    if v_at <= now() then raise exception 'A data de publicação tem de estar no futuro. Para publicar já, usa "Publicar".' using errcode = '22023'; end if;
  end if;
  update public.clues set
    status = p_status,
    publish_at = case when p_status = 'scheduled' then v_at when p_status = 'published' then coalesce(case when publish_at <= now() then publish_at end, now()) else publish_at end,
    published_at = case when p_status = 'published' then coalesce(published_at, now()) else published_at end,
    updated_at = now()
  where id = p_id returning * into c;
  if not found then raise exception 'Pista não encontrada.' using errcode = 'P0002'; end if;
  perform public._audit(case p_status when 'published' then 'pista_publicada' when 'scheduled' then 'pista_agendada'
                                      when 'archived' then 'pista_arquivada' else 'pista_despublicada' end,
                        'clue', c.id::text, jsonb_build_object('nome', c.internal_name, 'publish_at', c.publish_at));
  return public._clue_json(c);
end $$;

create or replace function public.admin_duplicate_clue(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare c public.clues;
begin
  perform public._require_admin();
  insert into public.clues (internal_name, title, teaser, content, image_url, extra_message, style, sort_order)
  select left(internal_name || ' (cópia)', 120), title, teaser, content, image_url, extra_message, style,
         coalesce((select max(sort_order) + 1 from public.clues), 1)
  from public.clues where id = p_id returning * into c;
  if not found then raise exception 'Pista não encontrada.' using errcode = 'P0002'; end if;
  perform public._audit('pista_duplicada', 'clue', c.id::text, jsonb_build_object('origem', p_id));
  return public._clue_json(c);
end $$;

create or replace function public.admin_delete_clue(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_name text;
begin
  perform public._require_admin();
  delete from public.clues where id = p_id returning internal_name into v_name;
  if v_name is null then raise exception 'Pista não encontrada.' using errcode = 'P0002'; end if;
  perform public._audit('pista_apagada', 'clue', p_id::text, jsonb_build_object('nome', v_name));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.admin_reorder_clues(p_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare i int;
begin
  perform public._require_admin();
  for i in 1 .. coalesce(array_length(p_ids, 1), 0) loop
    update public.clues set sort_order = i, updated_at = now() where id = p_ids[i];
  end loop;
  perform public._audit('pistas_reordenadas', 'clue', null, jsonb_build_object('ordem', to_jsonb(p_ids)));
  return jsonb_build_object('ok', true);
end $$;

-- Guarda nome/morada/link/mensagem. Não muda o estado de revelação.
create or replace function public.admin_save_location(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare l public.location_reveal; v_url text;
begin
  perform public._require_admin();
  v_url := public._txt(p, 'maps_url', 2048);
  if v_url <> '' and not public.is_valid_maps_url(v_url) then
    raise exception 'O link tem de ser um endereço https do Google Maps (google.com/maps, maps.app.goo.gl, ...).' using errcode = '22023';
  end if;
  select * into l from public.location_reveal where id = 1;
  if l.status <> 'hidden' and v_url = '' then
    raise exception 'Com a localização revelada ou agendada, o link do Google Maps é obrigatório.' using errcode = '22023';
  end if;
  update public.location_reveal set
    venue_name = public._txt(p, 'venue_name', 120, true), venue_address = public._txt(p, 'venue_address', 300),
    maps_url = v_url, reveal_message = public._txt(p, 'reveal_message', 600), updated_at = now()
  where id = 1 returning * into l;
  perform public._audit('localizacao_editada', 'location', '1', jsonb_build_object('estado', l.status));
  return to_jsonb(l) || jsonb_build_object('public', public._location_public());
end $$;

-- hidden | scheduled (p_reveal_at_local, hora de Lisboa) | revealed
create or replace function public.admin_set_location_status(p_status text, p_reveal_at_local text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare l public.location_reveal; v_at timestamptz;
begin
  perform public._require_admin();
  select * into l from public.location_reveal where id = 1;
  if p_status not in ('hidden', 'scheduled', 'revealed') then
    raise exception 'Estado inválido.' using errcode = '22023';
  end if;
  if p_status <> 'hidden' and not public.is_valid_maps_url(l.maps_url) then
    raise exception 'Guarda primeiro um link válido do Google Maps.' using errcode = '22023';
  end if;
  if p_status <> 'hidden' and (l.venue_name = '' or l.venue_name = 'Local a revelar') then
    raise exception 'Indica o nome verdadeiro do local antes de revelar.' using errcode = '22023';
  end if;
  if p_status = 'scheduled' then
    v_at := public._lisbon(p_reveal_at_local);
    if v_at is null or v_at <= now() then
      raise exception 'A data de revelação tem de estar no futuro.' using errcode = '22023';
    end if;
  end if;
  update public.location_reveal set
    status = p_status,
    reveal_at = case when p_status = 'scheduled' then v_at when p_status = 'hidden' then null else reveal_at end,
    revealed_at = case when p_status = 'revealed' then now() when p_status = 'hidden' then null else revealed_at end,
    updated_at = now()
  where id = 1 returning * into l;
  perform public._audit(case p_status when 'revealed' then 'localizacao_revelada' when 'scheduled' then 'localizacao_agendada'
                                      else 'localizacao_escondida' end,
                        'location', '1', jsonb_build_object('reveal_at', l.reveal_at, 'local', l.venue_name));
  return to_jsonb(l) || jsonb_build_object('public', public._location_public());
end $$;

create or replace function public.admin_list_suggestions()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin();
  return coalesce((select jsonb_agg(to_jsonb(s) order by s.created_at desc) from public.guest_suggestions s), '[]'::jsonb);
end $$;

create or replace function public.admin_update_suggestion(p_id uuid, p_status text, p_note text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare s public.guest_suggestions;
begin
  perform public._require_admin();
  if p_status not in ('new', 'reviewed', 'accepted', 'declined') then
    raise exception 'Estado inválido.' using errcode = '22023';
  end if;
  if char_length(coalesce(p_note, '')) > 1000 then
    raise exception 'Nota demasiado longa.' using errcode = '22023';
  end if;
  update public.guest_suggestions set status = p_status, admin_note = coalesce(p_note, ''), updated_at = now()
  where id = p_id returning * into s;
  if not found then raise exception 'Sugestão não encontrada.' using errcode = 'P0002'; end if;
  perform public._audit('sugestao_atualizada', 'suggestion', p_id::text, jsonb_build_object('estado', p_status));
  return to_jsonb(s);
end $$;

create or replace function public.admin_delete_suggestion(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._require_admin();
  delete from public.guest_suggestions where id = p_id;
  if not found then raise exception 'Sugestão não encontrada.' using errcode = 'P0002'; end if;
  perform public._audit('sugestao_apagada', 'suggestion', p_id::text, '{}'::jsonb);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.admin_audit(p_limit int default 100)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin();
  return coalesce((select jsonb_agg(to_jsonb(a) order by a.at desc)
                   from (select * from public.admin_audit_log order by at desc limit least(greatest(p_limit, 1), 500)) a), '[]'::jsonb);
end $$;

-- Pré-visualização: o site com os RASCUNHOS e todas as pistas não arquivadas.
create or replace function public.get_preview_site()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ev jsonb; ct jsonb; l public.location_reveal;
begin
  perform public._require_admin();
  select draft into ev from public.site_documents where key = 'event';
  select draft into ct from public.site_documents where key = 'content';
  select * into l from public.location_reveal where id = 1;
  return jsonb_build_object(
    'preview', true, 'server_time', now(), 'event', ev, 'times', public._event_times(ev), 'content', ct,
    'clues', coalesce((select jsonb_agg(jsonb_build_object(
        'id', c.id, 'title', c.title, 'teaser', c.teaser, 'content', c.content, 'image_url', c.image_url,
        'extra_message', c.extra_message, 'style', c.style, 'preview_status', c.status,
        'available_at', coalesce(c.publish_at, c.created_at)) order by c.sort_order, c.created_at)
      from public.clues c where c.status <> 'archived'), '[]'::jsonb),
    'upcoming', '[]'::jsonb,
    'location', case when l.maps_url <> '' then jsonb_build_object('state', 'revealed', 'venue_name', l.venue_name,
        'venue_address', l.venue_address, 'maps_url', l.maps_url, 'reveal_message', l.reveal_message, 'preview_real_state', l.status)
      else public._location_public() end);
end $$;

-- ---------------------------------------------------------------------
-- Permissões de execução
-- ---------------------------------------------------------------------
-- Por omissão o Postgres/Supabase deixa qualquer role executar funções.
-- Fechamos tudo e abrimos explicitamente.

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.get_public_site()                       to anon, authenticated;
grant execute on function public.submit_suggestion(text, text, text)     to anon, authenticated;
grant execute on function public.is_valid_maps_url(text)                 to anon, authenticated;

grant execute on function public.is_admin()                              to authenticated;
grant execute on function public.admin_whoami()                          to authenticated;
grant execute on function public.admin_get_state()                       to authenticated;
grant execute on function public.admin_save_document(text, jsonb)        to authenticated;
grant execute on function public.admin_publish_document(text)            to authenticated;
grant execute on function public.admin_discard_draft(text)               to authenticated;
grant execute on function public.admin_upsert_clue(jsonb)                to authenticated;
grant execute on function public.admin_set_clue_status(uuid, text, text) to authenticated;
grant execute on function public.admin_duplicate_clue(uuid)              to authenticated;
grant execute on function public.admin_delete_clue(uuid)                 to authenticated;
grant execute on function public.admin_reorder_clues(uuid[])             to authenticated;
grant execute on function public.admin_save_location(jsonb)              to authenticated;
grant execute on function public.admin_set_location_status(text, text)   to authenticated;
grant execute on function public.admin_list_suggestions()                to authenticated;
grant execute on function public.admin_update_suggestion(uuid, text, text) to authenticated;
grant execute on function public.admin_delete_suggestion(uuid)           to authenticated;
grant execute on function public.admin_audit(int)                        to authenticated;
grant execute on function public.get_preview_site()                      to authenticated;

-- As funções internas (_require_admin, _audit, _clean_*, ...) ficam sem
-- permissão para anon/authenticated: só são chamadas por dentro.

-- Linhas únicas iniciais (o texto vem do seed.sql).
insert into public.location_reveal (id) values (1) on conflict (id) do nothing;
