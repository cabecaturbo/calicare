-- Phase 2.1: households, members, children, and log events, with RLS.
--
-- Mirrors the app's SwiftData models (Core/Data/Schema/SchemaV1.swift).
-- Every row's id is a UUID made on the device. created_at, updated_at, and
-- deleted_at come from the device too; deletes are soft (deleted_at set).
-- server_updated_at is set here, by the server clock, and is what sync reads
-- "changes since" from, so a phone with a wrong clock can't be skipped.
-- Conflicts: last write wins by updated_at (see supabase/README.md).
-- No photos, no storage buckets.

-- MARK: - Tables

create type public.member_role as enum ('owner', 'caregiver');

create table public.households (
    id uuid primary key,
    name text not null default '' check (char_length(name) <= 80),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now()
);

create table public.household_members (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    role public.member_role not null,
    -- What others see: "Mom", "Dad", "Grandma".
    display_name text not null check (char_length(display_name) between 1 and 40),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    unique (household_id, user_id)
);

create table public.children (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    name text not null check (char_length(name) between 1 and 80),
    birth_date timestamptz,
    color_tag text not null default 'sage',
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    -- Lets log_events check that its child is in the same household.
    unique (id, household_id)
);

create table public.log_events (
    id uuid primary key,
    household_id uuid not null references public.households (id) on delete cascade,
    -- Optional, like the app's LogEvent.child.
    child_id uuid,
    -- LogType raw value. No check list, so an older server still accepts a
    -- type added by a newer app (the app treats unknown types the same way).
    type text not null check (char_length(type) between 1 and 40),
    -- LogValue raw value, e.g. "rough" for a nightRating.
    value text check (char_length(value) <= 40),
    note text check (char_length(note) <= 2000),
    -- LogEvent.timestamp: when it happened (not when it was saved).
    occurred_at timestamptz not null,
    -- Display name of whoever logged it, or "You" before signing in.
    logged_by text not null check (char_length(logged_by) between 1 and 40),
    -- EntrySource raw value: widget, intent, notification, app, watch.
    entry_source text not null check (char_length(entry_source) between 1 and 20),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    server_updated_at timestamptz not null default now(),
    foreign key (child_id, household_id)
        references public.children (id, household_id) on delete cascade
);

-- MARK: - Indexes for "changes since" sync

create index household_members_household_updated on public.household_members (household_id, updated_at);
create index children_household_updated on public.children (household_id, updated_at);
create index log_events_household_updated on public.log_events (household_id, updated_at);

create index household_members_household_server_updated on public.household_members (household_id, server_updated_at);
create index children_household_server_updated on public.children (household_id, server_updated_at);
create index log_events_household_server_updated on public.log_events (household_id, server_updated_at);

-- Membership lookups behind every RLS check.
create index household_members_user on public.household_members (user_id, household_id) where deleted_at is null;

-- MARK: - Membership helpers
-- security definer so policies on household_members don't recurse into themselves.

create function public.is_household_member(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.household_members m
        where m.household_id = target
          and m.user_id = (select auth.uid())
          and m.deleted_at is null
    );
$$;

create function public.is_household_owner(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.household_members m
        where m.household_id = target
          and m.user_id = (select auth.uid())
          and m.role = 'owner'
          and m.deleted_at is null
    );
$$;

revoke execute on function public.is_household_member(uuid) from public, anon;
revoke execute on function public.is_household_owner(uuid) from public, anon;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_owner(uuid) to authenticated;

-- MARK: - Triggers

-- Stamps the server clock, and applies last write wins: an update carrying an
-- older updated_at than the stored row is skipped (the newer row stays).
create function public.sync_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
        return null;
    end if;
    new.server_updated_at := now();
    return new;
end;
$$;

create trigger sync_stamp before insert or update on public.households
    for each row execute function public.sync_stamp();
create trigger sync_stamp before insert or update on public.household_members
    for each row execute function public.sync_stamp();
create trigger sync_stamp before insert or update on public.children
    for each row execute function public.sync_stamp();
create trigger sync_stamp before insert or update on public.log_events
    for each row execute function public.sync_stamp();

-- Only owners may soft-delete a child. (Hard deletes are blocked by RLS.)
create function public.guard_child_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.deleted_at is null and new.deleted_at is not null
       and (select auth.role()) = 'authenticated'
       and not public.is_household_owner(new.household_id) then
        raise exception 'Only a household owner can remove a child.'
            using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger guard_child_delete before update on public.children
    for each row execute function public.guard_child_delete();

-- Members may change their own display name or leave (soft delete), but only
-- owners change roles or remove someone else. RLS limits whose rows can be
-- touched; this stops a caregiver promoting themselves.
create function public.guard_member_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if (select auth.role()) = 'authenticated'
       and not public.is_household_owner(old.household_id)
       and (new.role is distinct from old.role
            or new.user_id is distinct from old.user_id
            or new.household_id is distinct from old.household_id) then
        raise exception 'Only a household owner can change roles.'
            using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger guard_member_update before update on public.household_members
    for each row execute function public.guard_member_update();

-- MARK: - Creating a household
-- The first owner can't insert through RLS (they aren't a member yet), so the
-- household and its owner row are created together here. Ids come from the app.

create function public.create_household(
    household_id uuid,
    household_name text,
    member_id uuid,
    display_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (select auth.uid()) is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;
    insert into public.households (id, name) values (household_id, coalesce(household_name, ''));
    insert into public.household_members (id, household_id, user_id, role, display_name)
        values (member_id, household_id, (select auth.uid()), 'owner', display_name);
end;
$$;

revoke execute on function public.create_household(uuid, text, uuid, text) from public, anon;
grant execute on function public.create_household(uuid, text, uuid, text) to authenticated;

-- MARK: - Row level security
-- Only household members read or write. Nothing for anon.

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.children enable row level security;
alter table public.log_events enable row level security;

revoke all on public.households, public.household_members, public.children, public.log_events from anon;

-- Households: members read; owners rename or retire. Created only through create_household.
create policy "Members read their household" on public.households
    for select to authenticated using (public.is_household_member(id));
create policy "Owners update their household" on public.households
    for update to authenticated
    using (public.is_household_owner(id)) with check (public.is_household_owner(id));

-- Members: everyone in the household sees who's in it. Owners update anyone;
-- others only themselves (display name, or leaving). Invites add members
-- through an Edge Function (prompt 2.4), not direct inserts.
create policy "Members read the member list" on public.household_members
    for select to authenticated using (public.is_household_member(household_id));
create policy "Owners or the member themselves update a membership" on public.household_members
    for update to authenticated
    using (public.is_household_owner(household_id) or user_id = (select auth.uid()))
    with check (public.is_household_owner(household_id) or user_id = (select auth.uid()));
create policy "Owners remove members; anyone can leave" on public.household_members
    for delete to authenticated
    using (public.is_household_owner(household_id) or user_id = (select auth.uid()));

-- Children: members read, add, and edit; only owners remove (soft delete is
-- guarded by trigger; hard delete by this policy).
create policy "Members read children" on public.children
    for select to authenticated using (public.is_household_member(household_id));
create policy "Members add children" on public.children
    for insert to authenticated with check (public.is_household_member(household_id));
create policy "Members edit children" on public.children
    for update to authenticated
    using (public.is_household_member(household_id))
    with check (public.is_household_member(household_id));
create policy "Owners delete children" on public.children
    for delete to authenticated using (public.is_household_owner(household_id));

-- Log events: any member logs, edits, and soft-deletes (Undo). No hard deletes.
create policy "Members read logs" on public.log_events
    for select to authenticated using (public.is_household_member(household_id));
create policy "Members add logs" on public.log_events
    for insert to authenticated with check (public.is_household_member(household_id));
create policy "Members edit logs" on public.log_events
    for update to authenticated
    using (public.is_household_member(household_id))
    with check (public.is_household_member(household_id));
