-- Add profile fields used by app profile editor
alter table public.profiles
  add column if not exists preferred_foot preferred_foot not null default 'Right',
  add column if not exists skill_level int not null default 5;

-- Complete match + persist Elo/match stats for participants
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

grant execute on function public.complete_match_and_apply_elo(uuid, int, int) to authenticated;
