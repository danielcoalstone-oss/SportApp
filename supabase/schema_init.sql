-- SportApp Supabase Setup (Schema + Indexes + RLS + Core RPC)
-- Run this in Supabase SQL Editor, or as a migration file.

create extension if not exists pgcrypto;

-- =========================
-- Enums
-- =========================
do $$ begin
  create type global_role as enum ('player', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type coach_status as enum ('none', 'active', 'expired', 'paused');
exception when duplicate_object then null; end $$;

do $$ begin
  create type football_position as enum
    ('GK','CB','LB','RB','LWB','RWB','DM','CM','AM','LM','RM','LW','RW','ST','CF','SS');
exception when duplicate_object then null; end $$;

do $$ begin
  create type preferred_foot as enum ('Left','Right','Both');
exception when duplicate_object then null; end $$;

do $$ begin
  create type rsvp_status as enum ('invited','going','maybe','declined','waitlisted');
exception when duplicate_object then null; end $$;

do $$ begin
  create type position_group as enum ('GK','DEF','MID','FWD','BENCH');
exception when duplicate_object then null; end $$;

do $$ begin
  create type match_event_type as enum ('goal','assist','yellow','red','save');
exception when duplicate_object then null; end $$;

do $$ begin
  create type match_status as enum ('scheduled','completed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_dispute_status as enum ('none','open','resolved');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_visibility as enum ('public','private');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_status as enum ('draft','published','completed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tournament_match_status as enum ('scheduled','completed','cancelled');
exception when duplicate_object then null; end $$;

-- =========================
-- Core Tables
-- =========================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null unique,
  avatar_url text,
  favorite_position text not null default 'Midfielder',
  preferred_positions football_position[] not null default '{}',
  city text not null default '',
  elo_rating int not null default 1400,
  matches_played int not null default 0,
  wins int not null default 0,
  global_role global_role not null default 'player',
  preferred_foot preferred_foot not null default 'Right',
  skill_level int not null default 5,
  coach_subscription_ends_at timestamptz,
  is_coach_subscription_paused boolean not null default false,
  is_suspended boolean not null default false,
  suspension_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text not null,
  phone_number text,
  booking_hint text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  organiser_ids uuid[] not null default '{}',
  club_location text,
  start_at timestamptz not null,
  duration_minutes int not null default 90 check (duration_minutes > 0),
  format text not null default '5v5',
  location_name text not null,
  address text,
  notes text not null default '',
  max_players int not null check (max_players > 0),
  is_private_game boolean not null default false,
  has_court_booked boolean not null default false,
  is_rating_game boolean not null default true,
  min_elo int not null default 1200,
  max_elo int not null default 1800,
  anyone_can_invite boolean not null default false,
  any_player_can_input_results boolean not null default false,
  entrance_without_confirmation boolean not null default false,
  invite_link text,
  status match_status not null default 'scheduled',
  final_home_score int,
  final_away_score int,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint match_score_nonnegative check (
    (final_home_score is null or final_home_score >= 0)
    and (final_away_score is null or final_away_score >= 0)
  ),
  constraint match_completed_requires_score check (
    status <> 'completed' or (final_home_score is not null and final_away_score is not null)
  )
);

create table if not exists public.match_teams (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  name text not null,
  side text not null check (side in ('home','away')),
  max_players int not null check (max_players > 0),
  created_at timestamptz not null default now(),
  unique (match_id, side),
  unique (id, match_id)
);

create table if not exists public.match_participants (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  name text not null,
  elo int not null default 1400,
  match_team_id uuid not null,
  position_group position_group not null default 'BENCH',
  rsvp_status rsvp_status not null default 'invited',
  invited_at timestamptz not null default now(),
  waitlisted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (match_id, user_id),
  foreign key (match_team_id, match_id) references public.match_teams(id, match_id) on delete cascade
);

create table if not exists public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  type match_event_type not null,
  minute int not null check (minute >= 0 and minute <= 200),
  player_id uuid not null references public.profiles(id),
  created_by_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.tournaments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  location text not null,
  start_date timestamptz not null,
  end_date timestamptz,
  visibility tournament_visibility not null default 'public',
  status tournament_status not null default 'published',
  entry_fee numeric(10,2) not null default 0,
  max_teams int not null check (max_teams >= 2),
  format text not null,
  owner_id uuid not null references public.profiles(id),
  organiser_ids uuid[] not null default '{}',
  dispute_status tournament_dispute_status not null default 'none',
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tournament_teams (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  name text not null,
  color_hex text not null default '#2D6CC4',
  max_players int not null default 6 check (max_players > 0),
  created_at timestamptz not null default now(),
  unique (tournament_id, name),
  unique (id, tournament_id)
);

create table if not exists public.tournament_team_members (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null,
  team_id uuid not null,
  user_id uuid not null references public.profiles(id),
  position_group position_group not null default 'BENCH',
  sort_order int not null default 0,
  is_captain boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (team_id, tournament_id) references public.tournament_teams(id, tournament_id) on delete cascade,
  unique (team_id, user_id),
  unique (tournament_id, user_id)
);

create table if not exists public.tournament_matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  home_team_id uuid not null references public.tournament_teams(id) on delete cascade,
  away_team_id uuid not null references public.tournament_teams(id) on delete cascade,
  start_time timestamptz not null,
  location_name text,
  status tournament_match_status not null default 'scheduled',
  home_score int,
  away_score int,
  is_completed boolean not null default false,
  matchday int,
  match_id uuid unique references public.matches(id) on delete set null,
  created_at timestamptz not null default now(),
  check (home_team_id <> away_team_id)
);

create table if not exists public.audit_logs (
  id bigserial primary key,
  actor_user_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- =========================
-- Indexes
-- =========================
create index if not exists idx_matches_start_at on public.matches(start_at);
create index if not exists idx_matches_status on public.matches(status);
create index if not exists idx_matches_owner on public.matches(owner_id);
create index if not exists idx_match_participants_match_status on public.match_participants(match_id, rsvp_status);
create index if not exists idx_match_events_match on public.match_events(match_id, minute);
create index if not exists idx_tournament_matches_tournament_start on public.tournament_matches(tournament_id, start_time);
create index if not exists idx_tournament_teams_tournament on public.tournament_teams(tournament_id);

-- =========================
-- Updated At Trigger
-- =========================
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_touch_updated_at on public.profiles;
create trigger trg_profiles_touch_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_matches_touch_updated_at on public.matches;
create trigger trg_matches_touch_updated_at
before update on public.matches
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_tournaments_touch_updated_at on public.tournaments;
create trigger trg_tournaments_touch_updated_at
before update on public.tournaments
for each row execute procedure public.touch_updated_at();

-- =========================
-- Auth -> Profile Seed Trigger
-- =========================
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, email, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

-- =========================
-- RBAC Helper Functions
-- =========================
create or replace function public.is_admin(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = p_uid and p.global_role = 'admin'::global_role
  );
$$;

create or replace function public.is_match_organiser(p_match_id uuid, p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and (m.owner_id = p_uid or p_uid = any(m.organiser_ids) or public.is_admin(p_uid))
  );
$$;

create or replace function public.is_tournament_organiser(p_tournament_id uuid, p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tournaments t
    where t.id = p_tournament_id
      and (t.owner_id = p_uid or p_uid = any(t.organiser_ids) or public.is_admin(p_uid))
  );
$$;

-- =========================
-- Core RPCs
-- =========================
create or replace function public.set_match_rsvp(
  p_match_id uuid,
  p_target_user_id uuid,
  p_desired_status rsvp_status
)
returns table (
  effective_status rsvp_status,
  message text,
  promoted_user_id uuid,
  promoted_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_match_status match_status;
  v_max_players int;
  v_prev_status rsvp_status;
  v_new_status rsvp_status;
  v_going_excluding_target int;
  v_going_count int;
  v_promoted_user_id uuid;
  v_promoted_name text;
  v_message text;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  select m.status, m.max_players
  into v_match_status, v_max_players
  from public.matches m
  where m.id = p_match_id and m.is_deleted = false
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_match_status <> 'scheduled' then
    raise exception 'Match is not open for RSVP';
  end if;

  if v_actor <> p_target_user_id and not public.is_match_organiser(p_match_id, v_actor) then
    raise exception 'You do not have permission';
  end if;

  perform 1
  from public.match_participants mp
  where mp.match_id = p_match_id
  for update;

  select mp.rsvp_status
  into v_prev_status
  from public.match_participants mp
  where mp.match_id = p_match_id and mp.user_id = p_target_user_id;

  if not found then
    raise exception 'Participant not found';
  end if;

  if p_desired_status = 'going' then
    select count(*)
    into v_going_excluding_target
    from public.match_participants mp
    where mp.match_id = p_match_id
      and mp.rsvp_status = 'going'
      and mp.user_id <> p_target_user_id;

    if v_going_excluding_target >= v_max_players then
      v_new_status := 'waitlisted';
      v_message := 'Match is full. You were added to the waitlist.';
      update public.match_participants
      set rsvp_status = 'waitlisted',
          waitlisted_at = coalesce(waitlisted_at, now())
      where match_id = p_match_id and user_id = p_target_user_id;
    else
      v_new_status := 'going';
      update public.match_participants
      set rsvp_status = 'going',
          waitlisted_at = null
      where match_id = p_match_id and user_id = p_target_user_id;
    end if;
  else
    v_new_status := p_desired_status;
    update public.match_participants
    set rsvp_status = p_desired_status,
        waitlisted_at = case
          when p_desired_status = 'waitlisted' then coalesce(waitlisted_at, now())
          else null
        end
    where match_id = p_match_id and user_id = p_target_user_id;
  end if;

  if v_prev_status <> 'declined' and v_new_status = 'declined' then
    select count(*)
    into v_going_count
    from public.match_participants mp
    where mp.match_id = p_match_id
      and mp.rsvp_status = 'going';

    if v_going_count < v_max_players then
      select mp.user_id, p.full_name
      into v_promoted_user_id, v_promoted_name
      from public.match_participants mp
      join public.profiles p on p.id = mp.user_id
      where mp.match_id = p_match_id and mp.rsvp_status = 'waitlisted'
      order by coalesce(mp.waitlisted_at, mp.invited_at), mp.created_at
      limit 1;

      if v_promoted_user_id is not null then
        update public.match_participants
        set rsvp_status = 'going', waitlisted_at = null
        where match_id = p_match_id and user_id = v_promoted_user_id;
      end if;
    end if;
  end if;

  return query
  select v_new_status, v_message, v_promoted_user_id, v_promoted_name;
end;
$$;

create or replace function public.complete_or_update_match_score(
  p_match_id uuid,
  p_home_score int,
  p_away_score int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  if p_home_score < 0 or p_away_score < 0 then
    raise exception 'Scores must be non-negative';
  end if;

  if not public.is_match_organiser(p_match_id, v_actor) then
    raise exception 'You do not have permission';
  end if;

  update public.matches
  set status = 'completed',
      final_home_score = p_home_score,
      final_away_score = p_away_score,
      updated_at = now()
  where id = p_match_id and is_deleted = false;

  if not found then
    raise exception 'Match not found';
  end if;

  update public.tournament_matches
  set is_completed = true,
      home_score = p_home_score,
      away_score = p_away_score
  where match_id = p_match_id;
end;
$$;

create or replace function public.complete_match_and_apply_elo(
  p_match_id uuid,
  p_home_score int,
  p_away_score int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_home_team_id uuid;
  v_away_team_id uuid;
  v_home_avg numeric;
  v_away_avg numeric;
  v_k numeric := 24;
  v_actual numeric;
  v_expected numeric;
  v_new_elo int;
  v_win_inc int;
  rec record;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  if p_home_score < 0 or p_away_score < 0 then
    raise exception 'Scores must be non-negative';
  end if;

  if not public.is_match_organiser(p_match_id, v_actor) then
    raise exception 'You do not have permission';
  end if;

  update public.matches
  set status = 'completed',
      final_home_score = p_home_score,
      final_away_score = p_away_score,
      updated_at = now()
  where id = p_match_id and is_deleted = false;

  if not found then
    raise exception 'Match not found';
  end if;

  select id into v_home_team_id
  from public.match_teams
  where match_id = p_match_id and side = 'home'
  limit 1;

  select id into v_away_team_id
  from public.match_teams
  where match_id = p_match_id and side = 'away'
  limit 1;

  if v_home_team_id is null or v_away_team_id is null then
    return;
  end if;

  with participant_pool as (
    select
      mp.user_id,
      case
        when mp.match_team_id = v_home_team_id then 'home'
        when mp.match_team_id = v_away_team_id then 'away'
        else null
      end as team_side,
      p.elo_rating as elo
    from public.match_participants mp
    join public.profiles p on p.id = mp.user_id
    where mp.match_id = p_match_id
      and mp.match_team_id in (v_home_team_id, v_away_team_id)
      and mp.rsvp_status in ('going', 'invited', 'maybe')
  )
  select
    avg(case when team_side = 'home' then elo end),
    avg(case when team_side = 'away' then elo end)
  into v_home_avg, v_away_avg
  from participant_pool;

  if v_home_avg is null then v_home_avg := 1400; end if;
  if v_away_avg is null then v_away_avg := 1400; end if;

  for rec in
    select
      mp.user_id,
      mp.match_team_id,
      p.elo_rating,
      p.matches_played,
      p.wins
    from public.match_participants mp
    join public.profiles p on p.id = mp.user_id
    where mp.match_id = p_match_id
      and mp.match_team_id in (v_home_team_id, v_away_team_id)
      and mp.rsvp_status in ('going', 'invited', 'maybe')
  loop
    if rec.match_team_id = v_home_team_id then
      if p_home_score > p_away_score then
        v_actual := 1;
        v_win_inc := 1;
      elsif p_home_score < p_away_score then
        v_actual := 0;
        v_win_inc := 0;
      else
        v_actual := 0.5;
        v_win_inc := 0;
      end if;
      v_expected := 1 / (1 + power(10, (v_away_avg - rec.elo_rating)::numeric / 400));
    else
      if p_away_score > p_home_score then
        v_actual := 1;
        v_win_inc := 1;
      elsif p_away_score < p_home_score then
        v_actual := 0;
        v_win_inc := 0;
      else
        v_actual := 0.5;
        v_win_inc := 0;
      end if;
      v_expected := 1 / (1 + power(10, (v_home_avg - rec.elo_rating)::numeric / 400));
    end if;

    v_new_elo := round(rec.elo_rating + v_k * (v_actual - v_expected));

    update public.profiles
    set elo_rating = greatest(v_new_elo, 0),
        matches_played = coalesce(matches_played, 0) + 1,
        wins = coalesce(wins, 0) + v_win_inc,
        updated_at = now()
    where id = rec.user_id;
  end loop;

  update public.tournament_matches
  set is_completed = true,
      home_score = p_home_score,
      away_score = p_away_score
  where match_id = p_match_id;
end;
$$;

grant execute on function public.set_match_rsvp(uuid, uuid, rsvp_status) to authenticated;
grant execute on function public.complete_or_update_match_score(uuid, int, int) to authenticated;
grant execute on function public.complete_match_and_apply_elo(uuid, int, int) to authenticated;

-- =========================
-- RLS
-- =========================
alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.matches enable row level security;
alter table public.match_teams enable row level security;
alter table public.match_participants enable row level security;
alter table public.match_events enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_teams enable row level security;
alter table public.tournament_team_members enable row level security;
alter table public.tournament_matches enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists profiles_read_all_auth on public.profiles;
create policy profiles_read_all_auth on public.profiles
for select to authenticated using (true);

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
for update to authenticated using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

drop policy if exists clubs_read on public.clubs;
create policy clubs_read on public.clubs
for select to authenticated using (is_active = true);

drop policy if exists clubs_admin_write on public.clubs;
create policy clubs_admin_write on public.clubs
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists matches_read on public.matches;
create policy matches_read on public.matches
for select to authenticated using (is_deleted = false);

drop policy if exists matches_insert_player_or_admin on public.matches;
create policy matches_insert_player_or_admin on public.matches
for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.is_suspended = false
      and p.global_role in ('player'::global_role, 'admin'::global_role)
  )
);

drop policy if exists matches_update_organiser_or_admin on public.matches;
create policy matches_update_organiser_or_admin on public.matches
for update to authenticated
using (public.is_match_organiser(id))
with check (public.is_match_organiser(id));

drop policy if exists matches_delete_organiser_or_admin on public.matches;
create policy matches_delete_organiser_or_admin on public.matches
for delete to authenticated using (public.is_match_organiser(id));

drop policy if exists match_teams_read on public.match_teams;
create policy match_teams_read on public.match_teams
for select to authenticated using (true);

drop policy if exists match_teams_write_organiser on public.match_teams;
create policy match_teams_write_organiser on public.match_teams
for all to authenticated
using (public.is_match_organiser(match_id))
with check (public.is_match_organiser(match_id));

drop policy if exists match_participants_read on public.match_participants;
create policy match_participants_read on public.match_participants
for select to authenticated using (true);

drop policy if exists match_participants_insert_organiser on public.match_participants;
create policy match_participants_insert_organiser on public.match_participants
for insert to authenticated
with check (public.is_match_organiser(match_id));

drop policy if exists match_participants_update_self_or_organiser on public.match_participants;
create policy match_participants_update_self_or_organiser on public.match_participants
for update to authenticated
using (user_id = auth.uid() or public.is_match_organiser(match_id))
with check (user_id = auth.uid() or public.is_match_organiser(match_id));

drop policy if exists match_participants_delete_organiser on public.match_participants;
create policy match_participants_delete_organiser on public.match_participants
for delete to authenticated using (public.is_match_organiser(match_id));

drop policy if exists match_events_read on public.match_events;
create policy match_events_read on public.match_events
for select to authenticated using (true);

drop policy if exists match_events_write_organiser on public.match_events;
create policy match_events_write_organiser on public.match_events
for all to authenticated
using (public.is_match_organiser(match_id))
with check (public.is_match_organiser(match_id));

drop policy if exists tournaments_read on public.tournaments;
create policy tournaments_read on public.tournaments
for select to authenticated using (is_deleted = false);

drop policy if exists tournaments_insert_player_or_admin on public.tournaments;
create policy tournaments_insert_player_or_admin on public.tournaments
for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.is_suspended = false
      and p.global_role in ('player'::global_role, 'admin'::global_role)
  )
);

drop policy if exists tournaments_write_organiser on public.tournaments;
create policy tournaments_write_organiser on public.tournaments
for all to authenticated
using (public.is_tournament_organiser(id))
with check (public.is_tournament_organiser(id));

drop policy if exists tournament_teams_read on public.tournament_teams;
create policy tournament_teams_read on public.tournament_teams
for select to authenticated using (true);

drop policy if exists tournament_teams_write_organiser on public.tournament_teams;
create policy tournament_teams_write_organiser on public.tournament_teams
for all to authenticated
using (public.is_tournament_organiser(tournament_id))
with check (public.is_tournament_organiser(tournament_id));

drop policy if exists tournament_members_read on public.tournament_team_members;
create policy tournament_members_read on public.tournament_team_members
for select to authenticated using (true);

drop policy if exists tournament_members_insert_self_or_organiser on public.tournament_team_members;
create policy tournament_members_insert_self_or_organiser on public.tournament_team_members
for insert to authenticated
with check (user_id = auth.uid() or public.is_tournament_organiser(tournament_id));

drop policy if exists tournament_members_delete_self_or_organiser on public.tournament_team_members;
create policy tournament_members_delete_self_or_organiser on public.tournament_team_members
for delete to authenticated
using (user_id = auth.uid() or public.is_tournament_organiser(tournament_id));

drop policy if exists tournament_matches_read on public.tournament_matches;
create policy tournament_matches_read on public.tournament_matches
for select to authenticated using (true);

drop policy if exists tournament_matches_write_organiser on public.tournament_matches;
create policy tournament_matches_write_organiser on public.tournament_matches
for all to authenticated
using (public.is_tournament_organiser(tournament_id))
with check (public.is_tournament_organiser(tournament_id));

drop policy if exists audit_admin_read on public.audit_logs;
create policy audit_admin_read on public.audit_logs
for select to authenticated using (public.is_admin());

drop policy if exists audit_admin_write on public.audit_logs;
create policy audit_admin_write on public.audit_logs
for insert to authenticated with check (public.is_admin());
