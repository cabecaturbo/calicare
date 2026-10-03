-- Phase 6.2: a child's product diary. What's used, since when, and the
-- family's own "never again" list with their reason.
create table public.products (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    child_id uuid not null,
    name text not null check (char_length(name) between 1 and 80),
    -- ProductCategory raw value.
    category text not null check (category in ('moisturizer', 'wash', 'laundry', 'clothing', 'other')),
    started_at timestamptz not null,
    stopped_at timestamptz,
    never_again boolean not null default false,
    reason text check (char_length(reason) <= 300),
    -- Restock reminders (6.3).
    restock_every_days int check (restock_every_days between 1 and 365),
    restocked_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

create index products_household_updated on public.products (household_id, updated_at);
create index products_household_server_updated on public.products (household_id, server_updated_at);
create trigger sync_stamp before insert or update on public.products
    for each row execute function public.sync_stamp();

alter table public.products enable row level security;
revoke all on public.products from anon;
create policy "Members read" on public.products
    for select to authenticated using (public.is_household_member(household_id));
create policy "Members add" on public.products
    for insert to authenticated with check (public.is_household_member(household_id));
create policy "Members edit" on public.products
    for update to authenticated
    using (public.is_household_member(household_id))
    with check (public.is_household_member(household_id));
