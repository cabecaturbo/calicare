# Supabase

The shared backend for syncing logs between a household's phones. The app
is local-first: everything works offline and without an account, and sync
is a bonus (Phase 2).

- Project: **calicare** in *cabecaturbo's Org*, ref `sbzuoqxgtbpobnrqqmhw`,
  US West (Oregon), Postgres 17.
- No secrets live here. The app's Supabase URL and anon key go in a
  gitignored xcconfig (prompt 2.2). AI calls go through Edge Functions only.
- No photos and no storage buckets. Children's photos never leave the phone.

## Tables

| Table | Mirrors | Notes |
|---|---|---|
| `households` | — | A family. Created with `create_household(...)`, which also adds the caller as owner. |
| `household_members` | — | `user_id`, `role` (`owner` or `caregiver`), `display_name` ("Mom", "Grandma"). |
| `children` | `Child` | `name`, `birth_date`, `color_tag`, `is_active`. |
| `log_events` | `LogEvent` | `child_id` (optional), `type`, `value`, `note`, `occurred_at`, `logged_by`, `entry_source`, `body_areas` (flares), `routine_step_id` (no foreign key). |
| `routine_steps` | `RoutineStep` | `child_id`, `name`, `time` (`morning` or `evening`), `sort_order`, `is_active`. |

App field → column: `LogEvent.timestamp` → `occurred_at`, `typeRaw` →
`type`, `valueRaw` → `value`, `entrySourceRaw` → `entry_source`,
`loggedBy` → `logged_by`, `bodyAreasRaw` → `body_areas` (nil ↔ empty),
`routineStepID` → `routine_step_id`, `RoutineStep.timeRaw` → `time`,
`RoutineStep.order` → `sort_order`, `Child.birthDate` → `birth_date`.
The daily skin answer is a log: type `skinToday`, value `calm`,
`littleItchy`, `flaring`, or `veryRough`. `needsSync` stays
on the phone; it isn't a column.

Every table has `id` (a UUID made on the device), `created_at`,
`updated_at`, `deleted_at`, and `server_updated_at`.

## Conflicts: last write wins by `updated_at`

Each row carries the `updated_at` of its last edit, stamped by the device
that made it. When two devices edit the same row, the one with the later
`updated_at` wins, whichever arrives first. The database enforces this: an
update carrying an older `updated_at` than the stored row is skipped (trigger
`sync_stamp`), so a late, offline edit can never overwrite a newer one.

Deletes are soft: `deleted_at` is set and synced like any other edit. Rows
are never hard-deleted by sync. Only account deletion (prompt 2.6) removes
rows, through an Edge Function.

## "Changes since": `server_updated_at`

`updated_at` comes from phone clocks, which can be wrong or arrive late from
an offline phone. So the server also stamps `server_updated_at` with its own
clock on every insert and update, and sync pulls "rows where
`server_updated_at` > my cursor". That way no change is ever skipped. Both
`(household_id, updated_at)` and `(household_id, server_updated_at)` are
indexed.

## Who can do what (RLS)

| | Owner | Caregiver | Anyone else |
|---|---|---|---|
| Read the household, members, children, logs | Yes | Yes | No |
| Add and edit logs, soft-delete logs (Undo) | Yes | Yes | No |
| Add and edit children | Yes | Yes | No |
| Add, edit, and soft-delete routine steps | Yes | Yes | No |
| Remove a child | Yes | **No** | No |
| Change roles, remove other members | Yes | **No** | No |
| Change own display name, leave | Yes | Yes | No |

Signed-out (anon) requests can't read or write anything. Members join
through invite Edge Functions (prompt 2.4), which use the service role.

## Working on it

```sh
supabase start          # local Supabase in Docker (Colima on this Mac)
supabase db reset       # re-apply migrations to the local database
supabase test db        # run the pgTAP tests in tests/database/
supabase db push        # apply new migrations to the real project
```

Run tests against the local database only, never the real project.
