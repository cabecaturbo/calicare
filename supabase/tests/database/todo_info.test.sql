-- To do + Info columns on plan_items: nullable, additive, checked. Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select has_column('public', 'plan_items', 'is_giving', 'plan items know if a supplement is given');
select col_is_null('public', 'plan_items', 'giving_times', 'giving times are optional');
select col_is_null('public', 'plan_items', 'plain_text', 'plain words are optional');
select col_is_null('public', 'plan_items', 'source_paragraph', 'the restored paragraph is optional');
select ok(
    'morning,bedtime' ~ '^(morning|afternoon|bedtime)(,(morning|afternoon|bedtime))*$'
    and not ('morning,noon' ~ '^(morning|afternoon|bedtime)(,(morning|afternoon|bedtime))*$'),
    'giving times only use the three blocks'
);

select * from finish();
rollback;
