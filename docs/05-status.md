# Status and handoff (September 26, 2026)

Where CaliCare stands at the end of Phase 1, for the local Claude Code session to pick up from.

## Where things are
- **Branches:** `main` holds the finished Phase 1. New work goes on its own branch and merges back through a PR, with CI. `claude/inspiring-lamport-rmzneg` is the Phase 1 working branch.
- **Phase 1 (one-tap logging) is built:** Prompts 1–6 from `docs/04-build-plan.md`.
- **Verified on the Mac (Xcode, iPhone 17 simulator):** clean build with no warnings, all 125 tests pass, and the app launches into onboarding.
- **CI:** `.github/workflows/ios.yml` runs on every push to this branch. It generates the project, builds, runs the tests, and fails on any warning in our sources.

## Notebook redesign (September 26, 2026)
- **DESIGN.md** (repo root) is now the design system. Newsreader replaced Fraunces and DM Sans; paper, ink, and indigo replaced cream and sage.
- **New pieces in Core:** `DesignSystem.swift` (tokens, the six type styles, spacing, corners), `LedgerRow`/`LedgerSection`, button styles, and the paper grain. `ContrastTests` checks every text/background pair.
- **Restyled:** Today, onboarding, Settings, the debug list, the sheets, all widgets, and the log confirmation. The leaf is gone; the app icon is an ink "c" on paper.
- **VisualSteps:** onboarding and Settings show real iOS 27 screenshots for the Home Screen and Lock Screen widgets. Action Button and Control Center are placeholders until they're recorded on a real iPhone.
- **Design review:** the `DesignReview` scheme captures step assets and screenshots; results are in `design-review/redesign/`.

## What's built (by prompt)
1. **Scaffold:** XcodeGen `project.yml` with App, WidgetsExtension, Core (framework), and CoreTests. Fraunces and DM Sans are bundled in Core with their OFL licenses. `DesignSystem.swift` holds the day and night palettes, type, spacing, and radii.
2. **Data:** SwiftData in the App Group: `Child`, `LogEvent` (`SchemaV1` plus a migration plan), `LogStore`, `ChildStore`, and `CurrentChildSetting`. `CareDay` runs 7 PM to 7 PM.
3. **App Intents:** log intents, `UndoLastIntent` (10-minute window), Siri phrases, a Control Center itch control, and the "Cali Care" alternative app name.
4. **Widgets:** a small Itchy widget, a medium quick-log widget, Lock Screen widgets, per-child configuration, and "Logged" with Undo after a tap.
5. **Notifications:**
   - A morning check-in (Good / Okay / Rough), skipped on days that already have a night rating.
   - Morning and evening routine reminders (Done / Snooze 30 min).
   - A Reminders section in Settings, and a one-time permission offer after the first log.
   - A debug-only "Try a notification" row.
6. **Onboarding and Today:** onboarding, a child switcher, last night, one-tap log buttons, today's timeline (edit or delete), the week strip, and a quick-logging setup guide.

## Decisions made (now kept in `docs/06-decisions.md`)
- **Identifiers:** bundle `com.cursorkittens.calicare` (`.widgets`, `.core`), App Group `group.com.cursorkittens.calicare`, team F2J8ZU2NQJ (CursorKittens LLC).
- **Fonts:** fixed-weight versions cut from the Google Fonts variable files. Fraunces 500/600 (opsz 36, SOFT 0, WONK 0) and DM Sans 400/500/600 (opsz 14).
- **Night palette:** only the background comes from the design docs; the other night colors are proposed values. Card #2A2521, ink #E8DFD2, muted #A89E92, accent #8FA995, severity #3A443C / #4F6655 / #8FA995. All text is at least 4.5:1 contrast.
- **Days:** a care day runs 7 PM to 7 PM, so a night belongs to the morning it ends.
- **Reminders:**
  - All reminders start off, at 7:00 / 7:30 / 19:00.
  - They're silent (no sound).
  - Check-ins are scheduled as one-offs for the next 14 days and recalculated after every log, undo, settings change, and app open.
  - Routines repeat daily.
  - The permission offer is shown at most once.
  - A late answer is logged at the check-in's own time.
- **Routine logs:** `routineDone` logs carry a morning or evening value; widget logs have none.

## Waiting on
- **Nothing blocking.** Development signing works: the iPhone 15 Pro is registered (`FPL7F2F9K3`) and CaliCare is installed on it.
- **After that:** do the Apple tooling setup (see below), then TestFlight.

## Open items
- **Apple token revocation on account deletion** (needed before App Store review): create a Sign in with Apple key on the Apple Developer site, store it as a Supabase secret, and have `delete-account` call Apple's revoke endpoint.
- **Two-phone test** for 2.4 (join with a code) and 2.5 ("by Dad" names).
- **No app icon:** `ASSETCATALOG_COMPILER_APPICON_NAME` is empty in `project.yml`. One is needed before TestFlight.

## Manual tests to do (the simulator can't cover these)
Test device: iPhone 15 Pro (has an Action Button).

- **Onboarding:** from install to the first widget log takes under a minute.
- **Widgets:** the small, medium, and Lock Screen widgets log without opening the app, and Undo works.
- **Siri and Action Button** (real device): "Log itching in CaliCare", and the itch shortcut assigned to the Action Button.
- **Control Center:** the itch control logs.
- **Notifications:** Good / Okay / Rough and Done / Snooze from the banner. They should work with the app closed too.
- **Night palette:** switches after 8 PM in the app and the widgets.
- **Accessibility:** VoiceOver labels and large Dynamic Type sizes.

## Apple tooling setup (once, on the Mac)
1. **Sign in to Xcode (done):** Xcode → Settings → Accounts → add your Apple ID, and check that CursorKittens LLC appears.
2. **`asc` (done):** signed in as profile `CursorKittens` (team key `XR2WW8YLM4`, App Manager; the `.p8` is in `~/.appstoreconnect/`). CaliCare has no App Store Connect record or registered bundle ID yet.
3. **Optional:** `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest` lets Claude drive the simulator.
4. **Allowlist (done):** `.claude/settings.json` allowing xcodegen, xcodebuild build/test, `xcrun simctl`, read-only `asc`, and git status/diff/log. Anything that uploads, submits, or pushes still asks.
5. **Rules (done):** the "Apple tooling" section in CLAUDE.md:
   - Use `-allowProvisioningUpdates` for device builds and archives.
   - Use `asc` for App Store Connect.
   - Never commit keys, certificates, or profiles.
   - Always ask before creating the app record, uploading, or submitting.

CLIs on the Mac (all installed with Homebrew): `asc`, `supabase`, `vercel`, and `gh`.
- **Signed in:** `gh` (as cabecaturbo) and `asc`. Still to do: `supabase login` and `vercel login` (not needed until Phase 2).
- **Supabase (Phase 2 started):** `supabase/` is set up and linked to the **calicare** project in *cabecaturbo's Org* (ref `sbzuoqxgtbpobnrqqmhw`, US West / Oregon, Postgres 17). The 2.1 schema (households, members, children, log events, RLS) is applied; see `supabase/README.md`. Don't run `vercel link` until Phase 7.

## Next steps
1. Use the app with the family for a few days and note what felt good or annoying (per the build plan).
2. Do the manual tests above on a real iPhone.
3. Finish the Apple tooling setup once access and the API key arrive, then do a first TestFlight build.
4. Write the Phase 2 prompts (Supabase schema + RLS, Sign in with Apple, sync, caregivers) around what was actually built.

## How to work (unchanged)
One prompt at a time, only what's asked, no features from later phases. Build and test after every change, fix all warnings, and commit once per completed prompt.
