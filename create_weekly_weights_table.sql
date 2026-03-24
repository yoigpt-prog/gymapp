-- Create the table to store per-week weight logs per user
create table if not exists public.user_weekly_weights (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  week_number   int  not null check (week_number >= 1),
  weight_kg     numeric(6,2) not null,
  logged_at     timestamptz not null default now(),

  -- one entry per user per week; upsert uses this constraint
  unique (user_id, week_number)
);

-- Row-level security
alter table public.user_weekly_weights enable row level security;

create policy "Users can manage their own weekly weights"
  on public.user_weekly_weights
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
