-- =====================================================================
--  SCOUTING · Aggiornamento FOTO (galleria per giocatore)
--  Incolla tutto in: Supabase → SQL Editor → New query → Run
--  Si può rieseguire senza problemi.
-- =====================================================================

-- 1. Nuovo tipo di dato "photos" nell'archivio
alter table public.records drop constraint if exists records_tipo_check;
alter table public.records add constraint records_tipo_check
  check (tipo in ('players','matches','reports','comments','photos'));

-- 2. Spazio file privato per le foto (max 5 MB a file, solo immagini)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('foto', 'foto', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 3. Permessi: tutti i membri vedono, solo lo scout carica/modifica/elimina
drop policy if exists "foto: lettura membri" on storage.objects;
drop policy if exists "foto: scout inserisce" on storage.objects;
drop policy if exists "foto: scout modifica"  on storage.objects;
drop policy if exists "foto: scout elimina"   on storage.objects;

create policy "foto: lettura membri" on storage.objects
  for select to authenticated using (bucket_id = 'foto' and public.is_member());
create policy "foto: scout inserisce" on storage.objects
  for insert to authenticated with check (bucket_id = 'foto' and public.is_scout());
create policy "foto: scout modifica" on storage.objects
  for update to authenticated using (bucket_id = 'foto' and public.is_scout())
  with check (bucket_id = 'foto' and public.is_scout());
create policy "foto: scout elimina" on storage.objects
  for delete to authenticated using (bucket_id = 'foto' and public.is_scout());

-- 4. Controllo: spazio occupato dalle foto
-- select count(*) as foto, pg_size_pretty(sum((metadata->>'size')::bigint)) as spazio
-- from storage.objects where bucket_id = 'foto';
