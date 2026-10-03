-- Phase 2.6: account deletion, part 1 (the data). The delete-account Edge
-- Function calls this as the person, then deletes their auth user with the
-- service role.
--
-- For each household the person is in: if they're its last owner, the whole
-- household goes (members, children, logs, invites cascade). Otherwise only
-- their membership goes, and the household carries on.

create function public.delete_my_account_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    me uuid := (select auth.uid());
    membership record;
begin
    if me is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;

    for membership in
        select m.household_id, m.role, m.deleted_at from public.household_members m where m.user_id = me
    loop
        if membership.role = 'owner' and membership.deleted_at is null and not exists (
            select 1 from public.household_members other
            where other.household_id = membership.household_id
              and other.user_id <> me
              and other.role = 'owner'
              and other.deleted_at is null
        ) then
            delete from public.households h where h.id = membership.household_id;
        else
            delete from public.household_members m
                where m.household_id = membership.household_id and m.user_id = me;
        end if;
    end loop;
end;
$$;

revoke execute on function public.delete_my_account_data() from public, anon;
grant execute on function public.delete_my_account_data() to authenticated;

-- Tells the app, before deleting, whether the household would go with it.
create function public.am_last_owner(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select public.is_household_owner(target) and not exists (
        select 1 from public.household_members other
        where other.household_id = target
          and other.user_id <> (select auth.uid())
          and other.role = 'owner'
          and other.deleted_at is null
    );
$$;

revoke execute on function public.am_last_owner(uuid) from public, anon;
grant execute on function public.am_last_owner(uuid) to authenticated;
