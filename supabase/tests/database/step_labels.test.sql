-- Step wording columns: nullable, additive, checked. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'owner@example.com');

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
    $$ insert into public.routine_steps (id, household_id, child_id, name, time, sort_order)
       values ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Bath', 'evening', 0) $$,
    'a step written without the new columns still saves'
);
select is((select label from public.routine_steps), null, 'new columns start empty');
select lives_ok(
    $$ update public.routine_steps set label = 'Take a bath', source_text = 'Bath', category = 'wash', kind = 'task',
       updated_at = now() + interval '1 second' $$,
    'a member can set the wording'
);
select is((select name from public.routine_steps), 'Bath', 'setting the wording leaves the name');
select throws_ok(
    $$ update public.routine_steps set category = 'treat', updated_at = now() + interval '2 seconds' $$,
    '23514', null,
    'only the five categories'
);
select throws_ok(
    $$ update public.routine_steps set kind = 'reminder', updated_at = now() + interval '3 seconds' $$,
    '23514', null,
    'a step is a task or a note'
);

select * from finish();
rollback;
