-- To do + Info: supplement giving and times, plain words, and the provider's
-- restored paragraph. Additive only: new nullable columns.
alter table public.plan_items
    add column is_giving boolean,
    -- TodoBlock raw values joined by commas: "morning,afternoon,bedtime".
    add column giving_times text check (giving_times ~ '^(morning|afternoon|bedtime)(,(morning|afternoon|bedtime))*$'),
    add column plain_text text check (char_length(plain_text) <= 2000),
    add column source_paragraph text check (char_length(source_paragraph) <= 4000);
