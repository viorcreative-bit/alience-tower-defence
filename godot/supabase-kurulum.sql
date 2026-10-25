-- Osmanlı Kale Savunması: çevrimiçi sıralama tablosu
-- Supabase > SQL Editor > New query: bunu yapıştırıp Run'a basın.

create table if not exists public.scores (
  id bigint generated always as identity primary key,
  device text not null,
  name text not null check (char_length(name) between 1 and 16),
  honor int not null default 0,
  stars int not null default 0,
  best_wave int not null default 0,
  duel_wins int not null default 0,
  updated_at timestamptz not null default now(),
  unique (device, name)
);

alter table public.scores enable row level security;

drop policy if exists "herkes okur" on public.scores;
drop policy if exists "herkes ekler" on public.scores;
drop policy if exists "herkes gunceller" on public.scores;
create policy "herkes okur" on public.scores for select using (true);
create policy "herkes ekler" on public.scores for insert with check (true);
create policy "herkes gunceller" on public.scores for update using (true);
