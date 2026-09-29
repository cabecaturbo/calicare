-- Phase 4.2: the per-day count behind parse-care-plan's rate limit.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'owner@example.com');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
    select set_config('role', 'authenticated', true),
           set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
select is(public.note_parse_use(), 1, 'the first read today counts 1');
select is(public.note_parse_use(), 2, 'the next counts 2');
select throws_ok($$ select count(*) from public.parse_usage $$, '42501', null, 'people can''t read the counts directly');

reset role;
select set_config('role', 'anon', true);
select throws_ok($$ select public.note_parse_use() $$, '42501', null, 'signed-out callers can''t count');

select * from finish();
rollback;
