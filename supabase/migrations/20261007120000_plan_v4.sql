-- Plan v4: the plan's length (set by the parent) and a supplement's dose
-- steps (set by the parent). Additive only: new nullable columns.
alter table public.care_plans
    add column length_weeks integer check (length_weeks between 1 and 104);
alter table public.plan_items
    -- JSON text: [{"amount": "4 drops", "startDate": "2026-10-12T00:00:00Z"}]
    add column dose_steps text check (char_length(dose_steps) <= 4000);
