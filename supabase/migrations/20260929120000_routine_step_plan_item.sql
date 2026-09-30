-- Phase 4.4: routine steps a started care plan made point at their plan item.
-- No foreign key, like log_events.routine_step_id: never block an upload.
alter table public.routine_steps add column plan_item_id uuid;
