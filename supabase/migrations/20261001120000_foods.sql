-- Phase 5.1: a child's food list. Status and who decided are the family's
-- own; the app never sets them.
create table public.foods (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    child_id uuid not null,
    name text not null check (char_length(name) between 1 and 80),
    family text check (char_length(family) <= 80),
    -- FoodStatus raw value.
    status text not null check (status in ('safe', 'testing', 'paused')),
    status_changed_at timestamptz not null default now(),
    decided_by text not null check (decided_by in ('plan', 'parent')),
    note text check (char_length(note) <= 500),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

create index foods_household_updated on public.foods (household_id, updated_at);
create index foods_household_server_updated on public.foods (household_id, server_updated_at);
create trigger sync_stamp before insert or update on public.foods
    for each row execute function public.sync_stamp();

alter table public.foods enable row level security;
revoke all on public.foods from anon;
create policy "Members read" on public.foods
    for select to authenticated using (public.is_household_member(household_id));
create policy "Members add" on public.foods
    for insert to authenticated with check (public.is_household_member(household_id));
create policy "Members edit" on public.foods
    for update to authenticated
    using (public.is_household_member(household_id))
    with check (public.is_household_member(household_id));
