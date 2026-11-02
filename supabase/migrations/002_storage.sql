-- =====================================================================
--  Imagens das pistas (opcional) — Supabase Storage
-- =====================================================================
--  Bucket público "clue-images": qualquer pessoa com o link consegue ver
--  a imagem; só administradores carregam, substituem ou apagam.
--  Os nomes são aleatórios (UUID), mas uma imagem de uma pista ainda
--  não publicada fica acessível a quem souber o link exato. Não uses
--  imagens que revelem o local antes da hora.
--  Corre DEPOIS de 001_schema.sql. Se não quiseres imagens, não corras.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clue-images', 'clue-images', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "festa50 admin upload"  on storage.objects;
drop policy if exists "festa50 admin update"  on storage.objects;
drop policy if exists "festa50 admin delete"  on storage.objects;

create policy "festa50 admin upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'clue-images' and public.is_admin());
create policy "festa50 admin update" on storage.objects for update to authenticated
  using (bucket_id = 'clue-images' and public.is_admin());
create policy "festa50 admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'clue-images' and public.is_admin());
-- Leitura: o bucket é público, não é preciso política de SELECT para servir imagens.
