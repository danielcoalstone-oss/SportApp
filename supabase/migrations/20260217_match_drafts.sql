alter table if exists public.matches
add column if not exists is_draft boolean not null default false;

create index if not exists idx_matches_is_draft_start_at
on public.matches (is_draft, start_at);
