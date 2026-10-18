-- =====================================================================
--  SCOUTING · Setup database Supabase
--  Incolla tutto in: Supabase → SQL Editor → New query → Run
--  Si può rieseguire senza problemi (è idempotente).
-- =====================================================================

-- ---------- 1. Profili utenti (ruolo: scout = modifica, staff = legge e commenta)
create table if not exists public.profili (
  id     uuid primary key references auth.users(id) on delete cascade,
  email  text,
  nome   text,
  ruolo  text not null default 'staff' check (ruolo in ('scout','staff'))
);
alter table public.profili enable row level security;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profili where id = auth.uid());
$$;

create or replace function public.is_scout() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profili where id = auth.uid() and ruolo = 'scout');
$$;

drop policy if exists "profili: lettura membri" on public.profili;
create policy "profili: lettura membri" on public.profili
  for select to authenticated using (public.is_member());

-- Ogni nuovo utente creato in Authentication riceve automaticamente un profilo "staff"
create or replace function public.nuovo_utente() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profili (id, email, nome)
  values (new.id, new.email, split_part(new.email, '@', 1))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.nuovo_utente();

-- Profili per eventuali utenti creati prima di questo script
insert into public.profili (id, email, nome)
select id, email, split_part(email, '@', 1) from auth.users
on conflict (id) do nothing;

-- ---------- 2. Archivio dati (giocatori, partite, osservazioni, commenti)
create table if not exists public.records (
  id          uuid primary key,
  tipo        text not null check (tipo in ('players','matches','reports','comments')),
  data        jsonb not null default '{}'::jsonb,
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);
create index if not exists records_updated_at_idx on public.records (updated_at);
alter table public.records enable row level security;

-- Timestamp lato server + vince sempre la modifica più recente
create or replace function public.records_stamp() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    if new.tipo <> old.tipo then
      raise exception 'tipo non modificabile';
    end if;
    if coalesce(new.data->>'updatedAt', '') < coalesce(old.data->>'updatedAt', '') then
      return old;           -- versione più vecchia: ignorata
    end if;
  end if;
  new.updated_at := clock_timestamp();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists records_stamp on public.records;
create trigger records_stamp
  before insert or update on public.records
  for each row execute function public.records_stamp();

-- Permessi
drop policy if exists "records: lettura membri"    on public.records;
drop policy if exists "records: scout inserisce"   on public.records;
drop policy if exists "records: scout modifica"    on public.records;
drop policy if exists "records: commento inserisce" on public.records;
drop policy if exists "records: commento modifica"  on public.records;

create policy "records: lettura membri" on public.records
  for select to authenticated using (public.is_member());

-- Lo scout gestisce giocatori, partite e osservazioni
create policy "records: scout inserisce" on public.records
  for insert to authenticated
  with check (public.is_scout() and tipo <> 'comments');
create policy "records: scout modifica" on public.records
  for update to authenticated
  using (public.is_scout() and tipo <> 'comments')
  with check (public.is_scout() and tipo <> 'comments');

-- Tutti i membri possono scrivere commenti (e modificare/eliminare solo i propri)
create policy "records: commento inserisce" on public.records
  for insert to authenticated
  with check (public.is_member() and tipo = 'comments' and data->>'autoreId' = auth.uid()::text);
create policy "records: commento modifica" on public.records
  for update to authenticated
  using (public.is_member() and tipo = 'comments' and data->>'autoreId' = auth.uid()::text)
  with check (tipo = 'comments' and data->>'autoreId' = auth.uid()::text);

-- ---------- 3. Funzione "ping" per tenere attivo il progetto gratuito
create or replace function public.ping() returns integer
language sql stable as $$ select 1 $$;
grant execute on function public.ping() to anon, authenticated;

-- =====================================================================
--  DOPO aver creato gli utenti in Authentication → Users:
--  imposta lo scout e i nomi visualizzati, ad esempio:
--
--  update public.profili set ruolo = 'scout', nome = 'Mario Rossi'   where email = 'scout@esempio.it';
--  update public.profili set nome = 'Presidente'                     where email = 'presidente@esempio.it';
--  update public.profili set nome = 'Direttore sportivo'             where email = 'ds@esempio.it';
--  update public.profili set nome = 'Allenatore'                     where email = 'mister@esempio.it';
-- =====================================================================
