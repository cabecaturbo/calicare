-- Account deletion: the last-owner rule. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
    ('11111111-1111-1111-1111-111111111111', 'mom@example.com'),
    ('22222222-2222-2222-2222-222222222222', 'dad@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'grandma@example.com'),
    ('44444444-4444-4444-4444-444444444444', 'solo@example.com'),
    ('55555555-5555-5555-5555-555555555555', 'neighbor@example.com');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

-- Shared household: Mom and Dad own it, Grandma is a caregiver. One child, one log.
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000001', '', 'bbbbbbbb-0000-0000-0000-000000000001', 'Mom');
insert into public.children (id, household_id, name) values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Cal');
insert into public.log_events (id, household_id, child_id, type, occurred_at, logged_by, entry_source)
    values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 'itchEpisode', now(), 'Mom', 'app');
reset role;
insert into public.household_members (id, household_id, user_id, role, display_name) values
    (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'owner', 'Dad'),
    (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'caregiver', 'Grandma');

-- A solo household, and a neighbor's household that must never be touched.
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000002', '', gen_random_uuid(), 'Solo');
insert into public.children (id, household_id, name) values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000002', 'Kid');
select pg_temp.act_as('55555555-5555-5555-5555-555555555555');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000003', '', gen_random_uuid(), 'Neighbor');

-- Anon can't call it.
reset role;
select set_config('role', 'anon', true), set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select public.delete_my_account_data() $$, '42501', null, 'anon can''t delete anything');

-- The caregiver deletes: only their membership goes.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select is(public.am_last_owner('aaaaaaaa-0000-0000-0000-000000000001'), false, 'a caregiver is never the last owner');
select public.delete_my_account_data();
reset role;
select is((select count(*) from public.household_members where user_id = '33333333-3333-3333-3333-333333333333')::int, 0,
    'a caregiver''s membership is removed');
select is((select count(*) from public.children where household_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int, 1,
    'the household keeps its children when a caregiver leaves');

-- Mom deletes while Dad is still an owner: the household carries on.
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select is(public.am_last_owner('aaaaaaaa-0000-0000-0000-000000000001'), false, 'Mom isn''t the last owner while Dad is one');
select public.delete_my_account_data();
reset role;
select is((select count(*) from public.households where id = 'aaaaaaaa-0000-0000-0000-000000000001')::int, 1,
    'the household stays when another owner remains');
select is((select count(*) from public.log_events where household_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int, 1,
    'its logs stay too');

-- Dad is now the last owner: deleting takes the household and everything in it.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is(public.am_last_owner('aaaaaaaa-0000-0000-0000-000000000001'), true, 'Dad is the last owner');
select public.delete_my_account_data();
reset role;
select is((select count(*) from public.households where id = 'aaaaaaaa-0000-0000-0000-000000000001')::int, 0,
    'the last owner deleting removes the household');
select is(
    (select count(*) from public.children where household_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int
    + (select count(*) from public.log_events where household_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int
    + (select count(*) from public.household_members where household_id = 'aaaaaaaa-0000-0000-0000-000000000001')::int,
    0, 'nothing is left of that household'
);

-- A solo owner deletes: their household goes; the neighbor's doesn't.
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select public.delete_my_account_data();
reset role;
select is((select count(*) from public.children where household_id = 'aaaaaaaa-0000-0000-0000-000000000002')::int, 0,
    'a solo owner''s household and children go');
select is((select count(*) from public.households where id = 'aaaaaaaa-0000-0000-0000-000000000003')::int, 1,
    'other households are untouched');

select * from finish();
rollback;
