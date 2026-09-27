-- Invite codes: who can make them, expiry, single use, and roles. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
    ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
    ('22222222-2222-2222-2222-222222222222', 'partner@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'grandma@example.com'),
    ('44444444-4444-4444-4444-444444444444', 'stranger@example.com');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000001', '', 'bbbbbbbb-0000-0000-0000-000000000001', 'Mom');

-- Owners make codes: 6 characters, no look-alikes, a week to use.
create temp table codes (label text, code text);
grant all on codes to authenticated;
insert into codes select 'partner', code from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'owner');
insert into codes select 'grandma', code from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'caregiver');
insert into codes select 'late', code from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'caregiver');
select matches((select code from codes where label = 'partner'), '^[A-HJ-NP-Z2-9]{6}$', 'codes are 6 easy-to-read characters');
select ok(
    (select expires_at from public.household_invites where code = (select code from codes where label = 'partner'))
        between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute',
    'codes expire in 7 days'
);
select is((select count(*) from public.household_invites)::int, 3, 'an owner sees their invites');

-- A stranger can't invite into someone else's household or see its codes.
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
select throws_ok(
    $$ select * from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'caregiver') $$,
    '42501', null, 'a stranger can''t create an invite'
);
select is((select count(*) from public.household_invites)::int, 0, 'a stranger can''t read invites');
select throws_ok($$ select public.accept_invite('ZZZZZZ', gen_random_uuid(), 'Me') $$,
    'CC001', null, 'an unknown code is refused');

-- The partner joins as an owner with their code.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
select is(
    public.accept_invite(lower((select code from codes where label = 'partner')) || ' ', 'bbbbbbbb-0000-0000-0000-000000000002', 'Dad'),
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    'a code joins its household (case and spaces don''t matter)'
);
select is((select role::text from public.household_members where user_id = '22222222-2222-2222-2222-222222222222'),
    'owner', 'a partner invite makes an owner');
select is((select count(*) from public.children)::int, 0, 'the new member can read the household (no children yet)');
select lives_ok(
    $$ select public.accept_invite((select code from codes where label = 'partner'), gen_random_uuid(), 'Dad') $$,
    'accepting again while already a member is harmless'
);

-- Single use: grandma can't reuse the partner's code.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select throws_ok(
    format($$ select public.accept_invite(%L, gen_random_uuid(), 'Grandma') $$, (select code from codes where label = 'partner')),
    'CC003', null, 'a code works only once'
);

-- Expired codes are refused.
reset role;
update public.household_invites set expires_at = now() - interval '1 minute'
    where code = (select code from codes where label = 'late');
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select throws_ok(
    format($$ select public.accept_invite(%L, gen_random_uuid(), 'Grandma') $$, (select code from codes where label = 'late')),
    'CC002', null, 'an expired code is refused'
);

-- A caregiver invite makes a caregiver, who can't invite others.
select public.accept_invite((select code from codes where label = 'grandma'), 'bbbbbbbb-0000-0000-0000-000000000003', 'Grandma');
select is((select role::text from public.household_members where user_id = '33333333-3333-3333-3333-333333333333'),
    'caregiver', 'a caregiver invite makes a caregiver');
select throws_ok(
    $$ select * from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'caregiver') $$,
    '42501', null, 'a caregiver can''t create invites'
);

-- Leaving and rejoining with a new code restores membership with the new role.
update public.household_members set deleted_at = now(), updated_at = now() + interval '1 second'
    where user_id = '33333333-3333-3333-3333-333333333333';
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
insert into codes select 'back', code from public.create_invite('aaaaaaaa-0000-0000-0000-000000000001', 'owner');
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select lives_ok(
    format($$ select public.accept_invite(%L, gen_random_uuid(), 'Nana') $$, (select code from codes where label = 'back')),
    'someone who left can rejoin with a new code'
);
select is(
    (select role::text || ' ' || display_name || ' ' || (deleted_at is null)::text
     from public.household_members where user_id = '33333333-3333-3333-3333-333333333333'),
    'owner Nana true', 'rejoining takes the new role and name'
);

select * from finish();
rollback;
