-- "Questions for the visit" on a provider visit (app SchemaV9), shown on the
-- doctor report. Optional, plain text. Push before shipping the app build
-- that sends it (visits without questions sync either way).
alter table public.visits
  add column if not exists questions text check (char_length(questions) <= 2000);
