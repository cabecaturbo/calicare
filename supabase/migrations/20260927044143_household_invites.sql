-- Phase 2.4: invite codes. An owner makes a 6-character code for a partner
-- (owner) or caregiver; it works once and expires after 7 days.
-- Implemented as database functions (not Edge Functions): same security,
-- testable with pgTAP, nothing extra to deploy.

create table public.household_invites (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households (id) on delete cascade,
    -- No 0/O or 1/I, so it reads cleanly aloud and at 2 AM.
    code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
    role public.member_role not null,
    created_by uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default now() + interval '7 days',
    accepted_at timestamptz,
    accepted_by uuid references auth.users (id) on delete set null
);

create index household_invites_household on public.household_invites (household_id, created_at);

alter table public.household_invites enable row level security;
revoke all on public.household_invites from anon;

-- Owners can see their household's invites. Everything else goes through the functions.
create policy "Owners read their invites" on public.household_invites
    for select to authenticated using (public.is_household_owner(household_id));

-- MARK: - create_invite

create function public.create_invite(target_household uuid, invite_role public.member_role)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    candidate text;
    bytes bytea;
begin
    if (select auth.uid()) is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;
    if not public.is_household_owner(target_household) then
        raise exception 'Only a household owner can invite.' using errcode = '42501';
    end if;

    loop
        bytes := extensions.gen_random_bytes(6);
        candidate := '';
        for i in 0..5 loop
            candidate := candidate || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
        end loop;
        exit when not exists (select 1 from public.household_invites i where i.code = candidate);
    end loop;

    return query
        insert into public.household_invites (household_id, code, role, created_by)
        values (target_household, candidate, invite_role, (select auth.uid()))
        returning household_invites.code, household_invites.expires_at;
end;
$$;

-- MARK: - accept_invite
-- Errors the app can explain: CC001 no such code, CC002 expired, CC003 already used.

create function public.accept_invite(invite_code text, member_id uuid, display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    invite public.household_invites;
    existing public.household_members;
    me uuid := (select auth.uid());
begin
    if me is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;

    select * into invite from public.household_invites i
        where i.code = upper(btrim(invite_code))
        for update;
    if not found then
        raise exception 'That code doesn''t match an invite.' using errcode = 'CC001';
    end if;

    select * into existing from public.household_members m
        where m.household_id = invite.household_id and m.user_id = me;

    -- Already in: nothing to do, and the code stays usable for someone else.
    if found and existing.deleted_at is null then
        return invite.household_id;
    end if;

    if invite.accepted_at is not null then
        raise exception 'That code has already been used.' using errcode = 'CC003';
    end if;
    if invite.expires_at <= now() then
        raise exception 'That code has expired.' using errcode = 'CC002';
    end if;

    if found then
        -- Rejoining after leaving.
        update public.household_members m
            set deleted_at = null, role = invite.role, display_name = accept_invite.display_name,
                -- Always newer than the leave, or last-write-wins would skip it.
                updated_at = greatest(now(), m.updated_at + interval '1 millisecond')
            where m.id = existing.id;
    else
        insert into public.household_members (id, household_id, user_id, role, display_name)
            values (member_id, invite.household_id, me, invite.role, accept_invite.display_name);
    end if;

    update public.household_invites i
        set accepted_at = now(), accepted_by = me
        where i.id = invite.id;

    return invite.household_id;
end;
$$;

revoke execute on function public.create_invite(uuid, public.member_role) from public, anon;
revoke execute on function public.accept_invite(text, uuid, text) from public, anon;
grant execute on function public.create_invite(uuid, public.member_role) to authenticated;
grant execute on function public.accept_invite(text, uuid, text) to authenticated;

-- MARK: - Guards apply to app requests only
-- The 2.1 guards checked auth.role(), which is still 'authenticated' inside
-- trusted functions like accept_invite (a rejoining member gets a new role).
-- current_user is 'authenticated' only for direct requests from the app.

create or replace function public.guard_child_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.deleted_at is null and new.deleted_at is not null
       and current_user = 'authenticated'
       and not public.is_household_owner(new.household_id) then
        raise exception 'Only a household owner can remove a child.'
            using errcode = '42501';
    end if;
    return new;
end;
$$;

create or replace function public.guard_member_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user = 'authenticated'
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
