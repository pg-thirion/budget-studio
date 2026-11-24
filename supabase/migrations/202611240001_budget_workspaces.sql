create table public.budget_workspaces (
  user_id uuid primary key references auth.users(id) on delete cascade,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object' and snapshot ? 'months'),
  revision integer not null check (revision > 0)
);
alter table public.budget_workspaces enable row level security;
revoke all on public.budget_workspaces from anon, authenticated;
grant select, insert, update on public.budget_workspaces to authenticated;
create policy "Read own workspace" on public.budget_workspaces for select to authenticated using ((select auth.uid()) = user_id);
create policy "Create own workspace" on public.budget_workspaces for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Update own workspace" on public.budget_workspaces for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
