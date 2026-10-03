-- Phase 4: care plans. The server keeps only what the parent confirmed:
-- plans once started (never drafts), their confirmed items, and visits.
-- The original file never leaves the phone, so there's no column for it.

create table public.care_plans (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    child_id uuid not null,
    provider text not null default '' check (char_length(provider) <= 120),
    plan_date timestamptz,
    -- CarePlanStatus raw value; drafts stay on the phone.
    status text not null check (status in ('active', 'ended')),
    started_at timestamptz,
    ended_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

-- One confirmed item, in the plan's own words, with where it came from.
create table public.plan_items (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    -- No foreign key to the plan, so an item never fails to upload because
    -- its plan hasn't arrived yet. The app ignores items it can't place.
    plan_id uuid not null,
    child_id uuid not null,
    -- PlanItemKind raw value; kept open so a newer app's kinds pass through.
    kind text not null check (char_length(kind) between 1 and 40),
    text text not null check (char_length(text) between 1 and 2000),
    dose text check (char_length(dose) <= 500),
    frequency text check (char_length(frequency) <= 500),
    timing text check (char_length(timing) <= 500),
    duration text check (char_length(duration) <= 500),
    source_page integer check (source_page between 1 and 500),
    source_line text check (char_length(source_line) <= 2000),
    -- Only confirmed items are ever stored here.
    is_confirmed boolean not null default true check (is_confirmed),
    sort_order integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

create table public.visits (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    child_id uuid not null,
    date timestamptz not null,
    provider text not null default '' check (char_length(provider) <= 120),
    notes text check (char_length(notes) <= 2000),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

-- "Changes since" sync, last write wins, and members-only access, like routine_steps.
do $$
declare t text;
begin
    foreach t in array array['care_plans', 'plan_items', 'visits'] loop
        execute format('create index %1$s_household_updated on public.%1$s (household_id, updated_at)', t);
        execute format('create index %1$s_household_server_updated on public.%1$s (household_id, server_updated_at)', t);
        execute format('create trigger sync_stamp before insert or update on public.%1$s
                        for each row execute function public.sync_stamp()', t);
        execute format('alter table public.%1$s enable row level security', t);
        execute format('revoke all on public.%1$s from anon', t);
        execute format('create policy "Members read" on public.%1$s
                        for select to authenticated using (public.is_household_member(household_id))', t);
        execute format('create policy "Members add" on public.%1$s
                        for insert to authenticated with check (public.is_household_member(household_id))', t);
        execute format('create policy "Members edit" on public.%1$s
                        for update to authenticated
                        using (public.is_household_member(household_id))
                        with check (public.is_household_member(household_id))', t);
    end loop;
end $$;
