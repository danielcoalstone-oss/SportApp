-- Seed one quick-booking example match for this week.
-- Safe to run multiple times: skips insert if a match with same location_name + notes exists.

with owner as (
  select p.id, p.full_name, p.elo_rating
  from public.profiles p
  order by p.created_at
  limit 1
),
players as (
  select p.id, p.full_name, p.elo_rating
  from public.profiles p
  order by p.created_at
  limit 8
),
new_match as (
  insert into public.matches (
    owner_id,
    organiser_ids,
    club_location,
    start_at,
    duration_minutes,
    format,
    location_name,
    address,
    notes,
    max_players,
    is_private_game,
    has_court_booked,
    is_rating_game,
    min_elo,
    max_elo,
    anyone_can_invite,
    any_player_can_input_results,
    entrance_without_confirmation,
    status
  )
  select
    o.id,
    array[o.id]::uuid[],
    'Downtown Arena',
    now() + interval '2 hours',
    90,
    '5v5',
    'Downtown Arena',
    'Austin, TX',
    'Seeded quick-booking match (this week)',
    10,
    false,
    true,
    true,
    1000,
    2500,
    true,
    false,
    false,
    'scheduled'
  from owner o
  where exists (select 1 from owner)
    and not exists (
      select 1
      from public.matches m
      where m.location_name = 'Downtown Arena'
        and m.notes = 'Seeded quick-booking match (this week)'
        and m.is_deleted = false
    )
  returning id, max_players
),
home_team as (
  insert into public.match_teams (match_id, name, side, max_players)
  select nm.id, 'Blue', 'home', greatest(nm.max_players / 2, 1)
  from new_match nm
  returning id, match_id
),
away_team as (
  insert into public.match_teams (match_id, name, side, max_players)
  select nm.id, 'Orange', 'away', greatest(nm.max_players / 2, 1)
  from new_match nm
  returning id, match_id
),
ranked_players as (
  select
    p.*,
    row_number() over (order by p.full_name, p.id) as rn
  from players p
),
participants as (
  insert into public.match_participants (
    match_id,
    user_id,
    name,
    elo,
    match_team_id,
    position_group,
    rsvp_status
  )
  select
    nm.id,
    rp.id,
    rp.full_name,
    rp.elo_rating,
    case when mod(rp.rn, 2) = 1 then ht.id else at.id end as match_team_id,
    'BENCH',
    'going'
  from new_match nm
  join ranked_players rp on true
  join home_team ht on ht.match_id = nm.id
  join away_team at on at.match_id = nm.id
  where rp.rn <= 8
  returning id
)
select
  (select count(*) from new_match) as matches_inserted,
  (select count(*) from participants) as participants_inserted;
