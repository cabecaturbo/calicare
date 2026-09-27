-- U2: routine steps and the new log columns. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
    ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'stranger@example.com');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

-- An owner with a household and a child.
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000001', 'Cal''s family',
                               'bbbbbbbb-0000-0000-0000-000000000001', 'Mom');
insert into public.children (id, household_id, name)
    values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Cal');

-- Routine steps
select lives_ok(
    $$ insert into public.routine_steps (id, household_id, child_id, name, time, sort_order)
       values ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Bath', 'evening', 0) $$,
    'a member can add a routine step'
);
select throws_ok(
    $$ insert into public.routine_steps (id, household_id, child_id, name, time)
       values ('eeeeeeee-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Nap', 'afternoon') $$,
    '23514', null,
    'a step is morning or evening'
);
select is((select count(*) from public.routine_steps)::int, 1, 'a member reads the household''s steps');

-- Last write wins: an older edit is ignored.
update public.routine_steps set name = 'Old name', updated_at = now() - interval '1 day'
    where id = 'eeeeeeee-0000-0000-0000-000000000001';
select is((select name from public.routine_steps where id = 'eeeeeeee-0000-0000-0000-000000000001'),
          'Bath', 'an older edit doesn''t replace a newer one');

-- Body areas and the routine step on logs.
insert into public.log_events (id, household_id, child_id, type, occurred_at, logged_by, entry_source, body_areas)
    values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
            'cccccccc-0000-0000-0000-000000000001', 'flare', now(), 'Mom', 'app', '{face,elbowCreases}');
select is((select body_areas from public.log_events where id = 'dddddddd-0000-0000-0000-000000000001'),
          '{face,elbowCreases}'::text[], 'a flare keeps its body areas');
insert into public.log_events (id, household_id, child_id, type, value, occurred_at, logged_by, entry_source)
    values ('dddddddd-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
            'cccccccc-0000-0000-0000-000000000001', 'skinToday', 'littleItchy', now(), 'Mom', 'notification');
select is((select body_areas from public.log_events where id = 'dddddddd-0000-0000-0000-000000000002'),
          '{}'::text[], 'logs without body areas get an empty list');
select lives_ok(
    $$ insert into public.log_events (id, household_id, child_id, type, value, occurred_at, logged_by, entry_source, routine_step_id)
       values ('dddddddd-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'routineDone', 'evening', now(), 'Mom', 'app',
               'eeeeeeee-0000-0000-0000-000000000099') $$,
    'a log can name a step that hasn''t synced yet'
);

-- A stranger sees no steps and can't add one.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select is((select count(*) from public.routine_steps)::int, 0, 'a stranger can''t read steps');
select throws_ok(
    $$ insert into public.routine_steps (id, household_id, child_id, name, time)
       values ('eeeeeeee-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Sneaky', 'morning') $$,
    '42501', null,
    'a stranger can''t add a step'
);

-- Steps can't be hard-deleted, even by a member.
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
delete from public.routine_steps where id = 'eeeeeeee-0000-0000-0000-000000000001';
select is((select count(*) from public.routine_steps)::int, 1, 'steps are only soft-deleted');

-- Deleting the household takes its steps with it.
reset role;
delete from public.households where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select is((select count(*) from public.routine_steps)::int, 0, 'a deleted household''s steps go too');

select * from finish();
rollback;
