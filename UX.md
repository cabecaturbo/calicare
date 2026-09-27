# UX.md — Cali Care (v2)

DESIGN.md says how things look. This file says what screens exist, what
goes on each one, in what order, and how people move between them. Follow
both. If the current app differs from this file, this file wins.

## 0. What we're building, and the bar
Job of the app: help a tired parent manage their child's skin simply.
Log in one tap, follow the provider's plan, and see (and share) whether
things are getting better.

Three tests for every screen and feature:
- Simple: a sleep-deprived parent understands it in 3 seconds.
- Beautiful: it could sit next to Apple's Health app without looking
  cheap.
- Robust: a dermatologist looking at our reports would take them seriously.

Reference apps (study their structure, not their look):
- Gentler Streak (2024 Apple Design Award, Social Impact): encouraging,
  never guilt-driven; progress measured against your own history.
  Closest match to our tone.
- Apple Health: summary first, detail on tap, clean charts.
- Huckleberry: the leading parent tracking app; one-tap logging,
  caregiver sync, free logging with paid answers.
- How We Feel: a check-in that takes seconds.

## 1. Rules that make it feel like a real app
1. Every screen has one job. Say it in one sentence before building it.
2. The most important thing is at the top; the most-used action is in the
   thumb zone (bottom third).
3. Use native iOS building blocks, styled with DESIGN.md: TabView,
   NavigationStack, List/Form, sheets with detents, toolbars, swipe
   actions, context menus. Don't hand-build what iOS provides. Stacks of
   custom VStacks inside a ScrollView are what make an app feel homemade.
4. Consistent navigation: drill down = push. Quick task = sheet.
5. Every screen has designed states: first run, normal, lots of data,
   offline, error. No blank screens, no spinners without words.
6. Progressive disclosure: the answer first, details on tap.
7. Nothing appears because "the feature exists." No placeholders, no
   "Coming soon." Unbuilt features are simply absent.
8. One way to do each thing on a given screen. No duplicate controls.

## 2. App structure
Three tabs. Nothing else is top-level.

| Tab | Job | SF Symbol |
|---|---|---|
| Today | Log, and see how last night and today are going | sun.horizon |
| Plan | Follow the care plan: routine, supplements, food, baths | list.bullet.clipboard |
| Progress | See whether things are getting better, and share it | chart.line.uptrend.xyaxis |

On every tab
- Header: child's name (tap to switch child or add one) on the left,
  Settings button on the right. Settings opens as a sheet.
- Plan and Progress also show a quick log bar above the tab bar: one big
  "Itchy" button and "Log…" (opens the full log sheet). Use
  tabViewBottomAccessory on iOS 26+, a bottom safe-area inset bar on
  older iOS. Today doesn't need it; its Log section is the same thing.

Navigation
- Push: entry detail, a day in Progress, a supplement's detail.
- Sheet (medium detent): logging with a value, editing an entry, the skin
  check-in, flare location, visual steps.
- Sheet (large): Settings, care plan import, report preview.
- Full screen: onboarding only.
- After any log: DESIGN.md's confirmation line ("Logged, 2:14 AM · Undo").
  Never an alert.

## 3. The measures (what makes the data legitimate)
Everything the app shows comes from these. Keep them few and consistent.
1. Night: Good / Okay / Rough, plus itchy wake-up times.
2. Skin today (new, daily, 5 seconds): "How was [name]'s skin today?"
   Calm / A little itchy / Flaring / Very rough. Maps to indigo steps
   1, 2, 4, 5. This is the source of every "skin by day" view.
   Asked once a day: on Today after 4 PM if not logged, and as an evening
   notification with the four answers as buttons (logs without opening
   the app).
3. Itch episodes and flares, with optional body areas.
4. Bowel movements, mood, routine done, notes.
5. Weekly check-in (later, optional): a validated 7-question caregiver
   questionnaire. POEM is the standard dermatologists use, but commercial
   use needs a paid license from the University of Nottingham. Don't use
   the POEM name or questions until that license exists. Until then,
   reports use our own measures and describe them plainly.

Rules: severity comes from symptoms (itch, sleep, how the skin feels),
never from how skin looks in color. No scores we invented get fancy names.

## 4. Today
Job: log in one tap and see how last night and today are going.

Day layout (7 AM – 8 PM), top to bottom:
1. Header: child name (display) with chevron, date in meta, Settings.
2. Last night: the lede sentence ("A rough night. 3 itchy wake-ups, up at
   2:14 and 4:40."). If not rated: "How was last night?" with Good, Okay,
   Rough as ledger choices; one tap logs it.
3. Skin today (after 4 PM, until answered): the four choices as ledger
   rows. Once answered, it collapses to one line: "Skin today: flaring."
4. Log: ledger rows Itchy, Flare, Bowel movement, Mood, Note (Photo in
   Phase 6). Right side: today's count or last time in meta.
   - Itchy logs instantly.
   - Flare logs instantly; the confirmation line adds "Add where," which
     opens a simple body outline to tap areas (optional, never required).
   - Bowel movement and Mood open a small sheet; one tap on an option logs.
   - Note opens a sheet with a text field.
5. Routine: today's steps with checks. If none: one row, "Set up your
   routine" → Plan.
6. Today so far: timeline (time on the left, event, "by Dad" when more
   than one caregiver). Swipe to delete, tap to edit.
7. This week: 7-night dot strip in one row. Tap → Progress.

Night layout (8 PM – 7 AM), a different layout, not just colors:
1. Child name only.
2. Log rows first and bigger (72pt): Itchy, Flare, Note.
3. Tonight so far.
Everything else is hidden.

First run: a one-line hint above Log: "Tap Itchy whenever it happens.
That's all it takes." Gone after the first log.

## 5. Plan
Job: follow the care plan without thinking about it.

Before a plan is imported:
1. Routine: morning and evening steps the parent entered. "Edit routine"
   at the end.
2. Reminders: routine and check-in times with toggles.
3. Care plan: appears only once import is built (Phase 4). Then it's one
   row: "Add your care plan. Import a PDF or photo from your provider."

After import (Phase 4+), sections in this order, each hidden if empty:
Today's steps, Supplements (active, what starts next and when), Food
(Phase 5), Provider (next visit, messages left), About this plan
(provider, date, the original file, blanks your provider left).

## 6. Progress
Job: show whether things are getting better, and share it.

1. Range: Week, Month, Since last visit (shown once a visit date exists;
   doctors think in visits).
2. Summary: the headline sentence and at most one "worth watching" line.
   Compared with this child's own history only.
3. Nights: dots on the indigo scale.
4. Skin by day: indigo bars from Skin today.
5. Itchy wake-ups: bar chart per night (Swift Charts, indigo, minimal
   gridlines, tabular figures).
6. Photos (Phase 6): the on-device photo timeline.
7. Days: ledger rows (date, one-line summary). Tap → that day's timeline.
8. Share: Weekly card, Doctor report, Caregiver card. Tap → preview sheet
   with Share.

Fewer than 3 days of logs: charts are replaced by one sentence: "After a
few days of logging, you'll see how things are going here." Share stays.

## 7. Settings (sheet)
Grouped List:
1. Children
2. Family: sign in, members, invite (Phase 2)
3. Reminders: morning check-in, skin check-in, routine reminders
4. Quick logging: Home Screen widget, Lock Screen widget, Action Button,
   Siri, Control Center (each opens VisualSteps)
5. Your data: export everything (CSV and PDF), what's stored where
6. Account: display name, sign out, delete account
7. About: how the app works (what each measure means, in plain words),
   privacy, "Not medical advice," version, support email
Debug list: debug builds only.

## 8. Onboarding (full screen, no account)
Install to first log in under 60 seconds when optional steps are skipped.
Thin progress line at the top.
1. Welcome: wordmark, one sentence ("Log your child's eczema in one tap,
   and keep their care plan in one place."), and one trust line in meta:
   "No ads. Photos never leave your phone. Not medical advice."
   Continue.
2. Your child: first name (required), birthday (optional).
3. Reminders: morning "How was last night?" and evening "How was their
   skin today?" toggles with times. Turning one on shows a short priming
   line, then the system permission prompt. Skip is a clear secondary
   button.
4. Log from anywhere: VisualSteps for the Home Screen widget; "Show me
   the Action Button too" is optional. Skip is always visible.
5. Land on Today with the first-run hint.
No account, paywall, or survey in onboarding.

## 9. Legitimacy checklist
- Reports say exactly what was measured and how ("Skin today is the
  parent's daily answer: calm, a little itchy, flaring, or very rough").
- No invented scores, no percentages that imply precision we don't have.
- Doctor report readable in 30 seconds on page one; detail after.
- Before launch, have a pediatric dermatologist (or an allergist or
  nurse who treats eczema) review the report layout and all wording.
- Every data point can be exported by the parent.

## 10. Every screen, every state
Build and screenshot: first run, normal, lots of data (30+ entries, long
names, two children), night layout (Today), largest Dynamic Type, offline.

## 11. References folder
Human-picked screenshots live in /design-reference with notes.md saying
what to take from each. Read them before building any screen. DESIGN.md
wins on looks; UX.md wins on structure.

## 12. Rebuild order (UX pass, before continuing Phase 3)
One prompt per session, same rules as docs/prompts/README.md.
- U1. App shell: three tabs, headers, Settings sheet on every tab, quick
  log bar on Plan and Progress, navigation rules.
- U2. Measures: add skinToday (daily) and flare body areas to the data
  model with a schema migration and tests; evening skin check-in
  notification with four action buttons.
- U3. Today: day and night layouts exactly as section 4, all states.
- U4. Onboarding: exactly as section 8, with VisualSteps.
- U5. Plan and Progress: as sections 5 and 6 with what exists today.
  Progress becomes the home for Phase 3's reports.
- U6. Review pass: screenshot every screen in every state into
  /design-review/ux/, check against UX.md and DESIGN.md, fix gaps.
