-- SportApp DB verification script
-- Run in Supabase SQL Editor. It reports PASS/FAIL checks.

with required_tables(name) as (
  values
    ('profiles'),
    ('clubs'),
    ('matches'),
    ('match_teams'),
    ('match_participants'),
    ('match_events'),
    ('tournaments'),
    ('tournament_teams'),
    ('tournament_team_members'),
    ('tournament_matches'),
    ('audit_logs')
),
required_columns(table_name, column_name) as (
  values
    ('profiles','id'),
    ('profiles','full_name'),
    ('profiles','email'),
    ('profiles','avatar_url'),
    ('profiles','favorite_position'),
    ('profiles','preferred_positions'),
    ('profiles','preferred_foot'),
    ('profiles','skill_level'),
    ('profiles','city'),
    ('profiles','elo_rating'),
    ('profiles','matches_played'),
    ('profiles','wins'),
    ('profiles','global_role'),
    ('profiles','is_suspended'),
    ('matches','id'),
    ('matches','owner_id'),
    ('matches','organiser_ids'),
    ('matches','start_at'),
    ('matches','location_name'),
    ('matches','max_players'),
    ('matches','status'),
    ('matches','final_home_score'),
    ('matches','final_away_score'),
    ('matches','is_deleted'),
    ('match_participants','match_id'),
    ('match_participants','user_id'),
    ('match_participants','rsvp_status'),
    ('match_participants','waitlisted_at'),
    ('tournaments','id'),
    ('tournaments','owner_id'),
    ('tournaments','organiser_ids'),
    ('tournaments','dispute_status'),
    ('tournament_matches','id'),
    ('tournament_matches','tournament_id'),
    ('tournament_matches','home_team_id'),
    ('tournament_matches','away_team_id'),
    ('tournament_matches','home_score'),
    ('tournament_matches','away_score'),
    ('tournament_matches','is_completed'),
    ('tournament_matches','match_id')
),
required_functions(name) as (
  values
    ('is_admin'),
    ('is_match_organiser'),
    ('is_tournament_organiser'),
    ('set_match_rsvp'),
    ('complete_or_update_match_score'),
    ('complete_match_and_apply_elo'),
    ('handle_new_auth_user')
),
required_enums(type_name) as (
  values
    ('global_role'),
    ('coach_status'),
    ('football_position'),
    ('preferred_foot'),
    ('rsvp_status'),
    ('position_group'),
    ('match_event_type'),
    ('match_status'),
    ('tournament_dispute_status')
)
select *
from (
  select
    'table:' || rt.name as check_name,
    case when c.relname is not null then 'PASS' else 'FAIL' end as status,
    case when c.relname is not null then 'exists' else 'missing' end as details
  from required_tables rt
  left join pg_class c on c.relname = rt.name and c.relkind = 'r'
  left join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'

  union all

  select
    'column:' || rc.table_name || '.' || rc.column_name as check_name,
    case when ic.column_name is not null then 'PASS' else 'FAIL' end as status,
    case when ic.column_name is not null then 'exists' else 'missing' end as details
  from required_columns rc
  left join information_schema.columns ic
    on ic.table_schema = 'public'
   and ic.table_name = rc.table_name
   and ic.column_name = rc.column_name

  union all

  select
    'function:' || rf.name as check_name,
    case when p.proname is not null then 'PASS' else 'FAIL' end as status,
    case when p.proname is not null then 'exists' else 'missing' end as details
  from required_functions rf
  left join pg_proc p on p.proname = rf.name
  left join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'

  union all

  select
    'enum:' || re.type_name as check_name,
    case when t.typname is not null then 'PASS' else 'FAIL' end as status,
    case when t.typname is not null then 'exists' else 'missing' end as details
  from required_enums re
  left join pg_type t on t.typname = re.type_name
  left join pg_namespace n on n.oid = t.typnamespace and n.nspname = 'public'

  union all

  select
    'rls_enabled:' || c.relname as check_name,
    case when c.relrowsecurity then 'PASS' else 'FAIL' end as status,
    case when c.relrowsecurity then 'enabled' else 'disabled' end as details
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'profiles','clubs','matches','match_teams','match_participants','match_events',
      'tournaments','tournament_teams','tournament_team_members','tournament_matches','audit_logs'
    )

  union all

  select
    'trigger:on_auth_user_created' as check_name,
    case when exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where t.tgname = 'on_auth_user_created'
        and n.nspname = 'auth'
        and c.relname = 'users'
        and not t.tgisinternal
    ) then 'PASS' else 'FAIL' end as status,
    case when exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where t.tgname = 'on_auth_user_created'
        and n.nspname = 'auth'
        and c.relname = 'users'
        and not t.tgisinternal
    ) then 'exists' else 'missing' end as details

  union all

  select
    'seed:clubs_count' as check_name,
    case when (select count(*) from public.clubs where is_active = true) > 0 then 'PASS' else 'WARN' end as status,
    (select count(*)::text from public.clubs where is_active = true) as details

  union all

  select
    'seed:admin_users' as check_name,
    case when (select count(*) from public.profiles where global_role = 'admin') > 0 then 'PASS' else 'WARN' end as status,
    (select count(*)::text from public.profiles where global_role = 'admin') as details

) checks
order by
  case status when 'FAIL' then 0 when 'WARN' then 1 else 2 end,
  check_name;
