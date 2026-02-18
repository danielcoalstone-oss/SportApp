alter table if exists public.practice_sessions
add column if not exists is_draft boolean not null default false;

create index if not exists idx_practice_is_draft
on public.practice_sessions (is_draft, start_date);
