-- Step wording: short labels next to each step's original words. Additive
-- only: new nullable columns, nothing renamed, dropped, or rewritten.
alter table public.routine_steps
    add column label text check (char_length(label) <= 80),
    add column detail text check (char_length(detail) <= 500),
    -- The step's original words, full length (name stays capped at 80).
    add column source_text text check (char_length(source_text) <= 2000),
    -- StepCategory raw value.
    add column category text check (category in ('wash', 'apply', 'give', 'feed', 'dress')),
    add column times_per_day integer check (times_per_day between 1 and 24),
    -- StepKind raw value: task (ticked off) or note (information only).
    add column kind text check (kind in ('task', 'note'));

alter table public.plan_items
    add column label text check (char_length(label) <= 80),
    add column detail text check (char_length(detail) <= 500),
    add column category text check (category in ('wash', 'apply', 'give', 'feed', 'dress')),
    -- Set on items split out of a list ("Continue A, B"); the original stays.
    add column parent_item_id uuid;
