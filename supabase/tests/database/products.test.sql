-- Phase 6.2: products. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

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
    $$ insert into public.products (id, household_id, child_id, name, category, started_at, never_again, reason)
       values ('77777777-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Lavender wash', 'wash', now(), true, 'Red cheeks') $$,
    'a member can add a product'
);
select throws_ok(
    $$ insert into public.products (id, household_id, child_id, name, category, started_at)
       values ('77777777-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
               'cccccccc-0000-0000-0000-000000000001', 'Cream', 'treatment', now()) $$,
    '23514', null,
    'only the known categories'
);
select is((select count(*) from public.products)::int, 1, 'a member reads the household''s products');

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
select is((select count(*) from public.products)::int, 0, 'a stranger can''t read products');

select * from finish();
rollback;
