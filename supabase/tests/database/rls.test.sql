-- RLS for households, members, children, and logs. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

-- People: an owner, a caregiver in the same household, and a stranger.
insert into auth.users (id, email) values
    ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
    ('22222222-2222-2222-2222-222222222222', 'caregiver@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'stranger@example.com');

-- Act as a signed-in user.
create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

-- The owner creates a household with a child and a log.
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
    $$ select public.create_household('aaaaaaaa-0000-0000-0000-000000000001', 'Cal''s family',
                                      'bbbbbbbb-0000-0000-0000-000000000001', 'Mom') $$,
    'a signed-in user can create a household'
);
insert into public.children (id, household_id, name)
    values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Cal');
insert into public.log_events (id, household_id, child_id, type, occurred_at, logged_by, entry_source)
    values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
            'cccccccc-0000-0000-0000-000000000001', 'itchEpisode', now(), 'Mom', 'widget');

-- The caregiver joins (invites come later through an Edge Function, which uses the service role).
reset role;
insert into public.household_members (id, household_id, user_id, role, display_name)
    values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
            '22222222-2222-2222-2222-222222222222', 'caregiver', 'Grandma');

-- A stranger sees nothing and can't write in.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select is((select count(*) from public.households)::int, 0, 'a stranger can''t read the household');
select is((select count(*) from public.household_members)::int, 0, 'a stranger can''t read its members');
select is((select count(*) from public.children)::int, 0, 'a stranger can''t read its children');
select is((select count(*) from public.log_events)::int, 0, 'a stranger can''t read its logs');
select throws_ok(
    $$ insert into public.log_events (id, household_id, type, occurred_at, logged_by, entry_source)
       values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'itchEpisode', now(), 'Me', 'app') $$,
    '42501', null, 'a stranger can''t log into the household'
);

-- The caregiver can read and log, but can't delete a child or remove members.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is((select count(*) from public.children)::int, 1, 'a caregiver reads the household''s children');
select lives_ok(
    $$ insert into public.log_events (id, household_id, child_id, type, occurred_at, logged_by, entry_source)
       values ('dddddddd-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'nightRating', now(), 'Grandma', 'app') $$,
    'a caregiver can log'
);
delete from public.children where id = 'cccccccc-0000-0000-0000-000000000001';
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select is((select count(*) from public.children)::int, 1, 'a caregiver can''t hard-delete a child');
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select throws_ok(
    $$ update public.children set deleted_at = now(), updated_at = now() + interval '1 second'
       where id = 'cccccccc-0000-0000-0000-000000000001' $$,
    '42501', null, 'a caregiver can''t soft-delete a child'
);
update public.household_members set deleted_at = now(), updated_at = now() + interval '1 second'
    where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select is(
    (select deleted_at from public.household_members where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
    null, 'a caregiver can''t remove another member'
);
select throws_ok(
    $$ update public.household_members set role = 'owner', updated_at = now() + interval '1 second'
       where id = 'bbbbbbbb-0000-0000-0000-000000000002' $$,
    '42501', null, 'a caregiver can''t make themselves an owner'
);
select lives_ok(
    $$ update public.household_members set display_name = 'Nana', updated_at = now() + interval '1 second'
       where id = 'bbbbbbbb-0000-0000-0000-000000000002' $$,
    'a caregiver can change their own display name'
);

-- The owner can remove a child (soft delete).
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
    $$ update public.children set deleted_at = now(), updated_at = now() + interval '2 seconds'
       where id = 'cccccccc-0000-0000-0000-000000000001' $$,
    'an owner can soft-delete a child'
);

-- Last write wins by updated_at.
update public.log_events set note = 'newer', updated_at = now() + interval '1 hour'
    where id = 'dddddddd-0000-0000-0000-000000000001';
update public.log_events set note = 'older', updated_at = now() - interval '1 hour'
    where id = 'dddddddd-0000-0000-0000-000000000001';
select is(
    (select note from public.log_events where id = 'dddddddd-0000-0000-0000-000000000001'),
    'newer', 'an older edit never overwrites a newer one'
);
select ok(
    (select server_updated_at from public.log_events where id = 'dddddddd-0000-0000-0000-000000000001') is not null,
    'the server stamps server_updated_at'
);

-- Signed-out (anon) sees nothing and can't create households.
reset role;
select set_config('role', 'anon', true), set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select count(*) from public.log_events $$, '42501', null, 'anon can''t read logs');
select throws_ok(
    $$ select public.create_household(gen_random_uuid(), 'x', gen_random_uuid(), 'x') $$,
    '42501', null, 'anon can''t create a household'
);

-- No storage buckets: photos never leave the device.
reset role;
select is((select count(*) from storage.buckets)::int, 0, 'there are no storage buckets');

select * from finish();
rollback;
