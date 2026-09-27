# Phase 2: Sync and caregivers

Goal: two parents (and grandma) see the same logs, while the app keeps
working fully offline and without an account.

Before starting this phase, read docs/family-test-notes.md and flag anything
in these prompts that the notes suggest changing.

---

## 2.1 Supabase schema and RLS
If /supabase already exists with migrations, verify it against this list,
fix gaps, and mark done.

🛑 Manual first: Supabase project created, `brew install supabase/tap/supabase`,
`supabase login`.

1. Initialize /supabase and link it to the project (tell me the command
   with my project ref).
2. Migrations for: households; household_members (user_id, role owner or
   caregiver, display_name); children (belongs to household); log_events
   (all LogEvent fields including logged_by and entry_source).
3. Every table: id (UUID created on device), created_at, updated_at,
   deleted_at.
4. RLS on every table: only household members read or write. Caregivers
   can log but can't delete children or remove members.
5. Index on (household_id, updated_at) for "changes since" sync.
6. Conflict rule: last write wins by updated_at. Document in
   /supabase/README.md.
7. No photos, no storage buckets.
8. SQL tests: a stranger can't read a household; a caregiver can't delete
   a child.
Done when: migrations apply, RLS tests pass, no secrets in the repo.

---

## 2.2 🛑 Sign in with Apple (optional account)
Manual (list exact steps, then stop until confirmed): Sign in with Apple
capability on the App ID; Apple provider enabled in Supabase with Services
ID and key; Supabase URL and anon key added to an xcconfig that is
gitignored, with a committed example file.

1. Add the supabase-swift package (approved exception to the no-packages
   rule; add nothing else).
2. The app works exactly as before without an account. Signing in is
   offered, never required, from Settings and after onboarding
   ("Share logs with your partner").
3. Sign in with Apple → Supabase session stored in the Keychain, shared
   via a keychain access group so extensions can read it later.
4. Ask for a display name ("What should others see? e.g. Mom, Dad, Grandma").
5. Sign out keeps all local data on the phone.
6. Tests for the auth state logic (signed out, signed in, expired).
Done when: sign in and sign out work on a real device, the app still works
fully signed out, build and tests pass.

---

## 2.3 Background sync engine
1. SyncEngine in Core. Push: upload rows with needsSync = true (upsert by
   id), then clear the flag. Pull: fetch rows changed since the last
   cursor (stored in App Group defaults), merge by updated_at.
2. Soft deletes sync as deleted_at, never as hard deletes.
3. On first sign in: create a household, move existing local children and
   logs into it, and upload them.
4. Triggers: app foreground, a few seconds after any log (debounced), and
   BGAppRefreshTask. Widgets and intents only mark needsSync; the app
   does the sync.
5. Offline or errors: retry quietly with backoff. Never show sync errors
   during logging. A small "Last synced" line in Settings is enough.
6. Tests with a fake remote: push, pull, conflict (newer wins), delete
   syncs, offline queue, first sign-in migration.
Done when: a log on the simulator appears in Supabase, an edit in Supabase
appears in the app, tests pass.

---

## 2.4 Households and caregiver invites
1. Edge Function `create-invite`: owner creates a 6-character code,
   expires in 7 days, single use, role owner or caregiver.
2. Edge Function `accept-invite`: signed-in user joins the household.
   If they have local data from their own household, ask before merging.
3. Invite screen: "Invite your partner" or "Invite a caregiver," shows
   the code with a share sheet message. (A link on the Vercel site comes
   in Phase 7.)
4. Members list: names and roles. Owners can remove members; caregivers
   can leave.
5. Tests for code expiry, single use, and role rules.
Done when: a second account on another device joins with a code and sees
the same logs, tests pass.

---

## 2.5 "Logged by" names
1. loggedBy uses the member's display name when signed in, "You" when not.
2. Timeline entries show who logged them in muted text ("by Dad").
3. Widgets' last-logged line includes the name when the household has more
   than one member.
4. Intent confirmations stay short; no name needed ("Logged itchy wake-up,
   2:14 AM").
5. No notifications to other parents in this prompt.
Done when: two devices show correct names, build passes.

---

## 2.6 Account settings and account deletion
Account deletion inside the app is required by the App Store.
1. Settings → Account: display name, household members, sign out, delete
   account.
2. Edge Function `delete-account`: deletes the user's membership and, if
   they are the last owner, the household and all its rows. Deletes the
   auth user.
3. Clear, calm confirmation that says exactly what gets deleted and that
   data on this phone stays unless they also choose "Delete data on this
   phone."
4. Tests for the last-owner rule.
Done when: deletion works end to end and nothing is left in Supabase for
that household.
