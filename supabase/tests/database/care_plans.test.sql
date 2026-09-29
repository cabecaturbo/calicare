-- Phase 4: care plans, confirmed items, and visits. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email) values
    ('11111111-1111-1111-1111-111111111111', 'owner@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'stranger@example.com');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select public.create_household('aaaaaaaa-0000-0000-0000-000000000001', 'Cal''s family',
                               'bbbbbbbb-0000-0000-0000-000000000001', 'Mom');
insert into public.children (id, household_id, name)
    values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Cal');

select lives_ok(
    $$ insert into public.care_plans (id, household_id, child_id, provider, status, started_at)
       values ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Dr. Lee', 'active', now()) $$,
    'a member can add a started plan'
);
select throws_ok(
    $$ insert into public.care_plans (id, household_id, child_id, status)
       values ('ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'draft') $$,
    '23514', null,
    'drafts never reach the server'
);
select lives_ok(
    $$ insert into public.plan_items (id, household_id, plan_id, child_id, kind, text, frequency, source_page, source_line)
       values ('99999999-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'ffffffff-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
               'bath', 'Oat bath', '3 times a week', 1, 'Oat bath 3x/week') $$,
    'a member can add a confirmed item'
);
select throws_ok(
    $$ insert into public.plan_items (id, household_id, plan_id, child_id, kind, text, is_confirmed)
       values ('99999999-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'ffffffff-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
               'supplement', 'Vitamin D', false) $$,
    '23514', null,
    'unconfirmed items never reach the server'
);
select is((select dose from public.plan_items where id = '99999999-0000-0000-0000-000000000001'),
          null, 'a blank stays blank');
select lives_ok(
    $$ insert into public.visits (id, household_id, child_id, date, provider)
       values ('88888888-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', now(), 'Dr. Lee') $$,
    'a member can add a visit'
);

-- Last write wins.
update public.care_plans set status = 'ended', updated_at = now() - interval '1 day'
    where id = 'ffffffff-0000-0000-0000-000000000001';
select is((select status from public.care_plans where id = 'ffffffff-0000-0000-0000-000000000001'),
          'active', 'an older edit doesn''t replace a newer one');

-- A stranger sees none of it and can't write in.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select is((select count(*) from public.care_plans)::int, 0, 'a stranger can''t read plans');
select is((select count(*) from public.plan_items)::int + (select count(*) from public.visits)::int, 0,
          'a stranger can''t read items or visits');
select throws_ok(
    $$ insert into public.visits (id, household_id, child_id, date)
       values ('88888888-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', now()) $$,
    '42501', null,
    'a stranger can''t add a visit'
);

select * from finish();
rollback;
