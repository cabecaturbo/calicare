-- U2: the new measures. skinToday needs no change here: it's a log type
-- ("skinToday") with its answer in `value`, like a night rating.

-- Flare body areas (BodyArea raw values) and the routine step a
-- routineDone log ticks off.
alter table public.log_events
    add column body_areas text[] not null default '{}'
        check (cardinality(body_areas) <= 20),
    -- No foreign key, so a log never fails to upload because its step hasn't
    -- arrived yet. The app ignores ids it doesn't know.
    add column routine_step_id uuid;

-- One step of a child's morning or evening routine.
create table public.routine_steps (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    child_id uuid not null,
    name text not null check (char_length(name) between 1 and 80),
    -- RoutineTime raw value.
    time text not null check (time in ('morning', 'evening')),
    sort_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

-- "Changes since" sync, like the other tables.
create index routine_steps_household_updated on public.routine_steps (household_id, updated_at);
create index routine_steps_household_server_updated on public.routine_steps (household_id, server_updated_at);

-- Last write wins, and the server stamps its own time.
create trigger sync_stamp before insert or update on public.routine_steps
    for each row execute function public.sync_stamp();

-- Any member reads, adds, and edits steps; removing is a soft delete. No hard deletes.
alter table public.routine_steps enable row level security;
revoke all on public.routine_steps from anon;

create policy "Members read routine steps" on public.routine_steps
    for select to authenticated using (public.is_household_member(household_id));
create policy "Members add routine steps" on public.routine_steps
    for insert to authenticated with check (public.is_household_member(household_id));
create policy "Members edit routine steps" on public.routine_steps
    for update to authenticated
    using (public.is_household_member(household_id))
    with check (public.is_household_member(household_id));
