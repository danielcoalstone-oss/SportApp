-- Tournament organiser MVP incremental migration.
-- Safe to run multiple times.

do $$ begin
  create type tournament_visibility as enum ('public', 'private');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_status as enum ('draft', 'published', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_match_status as enum ('scheduled', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

alter table public.tournaments
  add column if not exists end_date timestamptz,
  add column if not exists visibility tournament_visibility not null default 'public',
  add column if not exists status tournament_status not null default 'published';

alter table public.tournament_teams
  add column if not exists color_hex text not null default '#2D6CC4';

alter table public.tournament_team_members
  add column if not exists position_group position_group not null default 'BENCH',
  add column if not exists sort_order int not null default 0,
  add column if not exists is_captain boolean not null default false;

alter table public.tournament_matches
  add column if not exists location_name text,
  add column if not exists status tournament_match_status not null default 'scheduled',
  add column if not exists matchday int;

update public.tournament_matches
set status = case when is_completed then 'completed'::tournament_match_status else 'scheduled'::tournament_match_status end
where status is null;

create index if not exists idx_tournament_matches_matchday
  on public.tournament_matches (tournament_id, matchday);
