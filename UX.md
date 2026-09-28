# UX.md — Cali Care (v2)

**This file describes the app as it is on the owner's phone (main, September
27, 2026).** The phone is the reference; where this file and the phone
disagree, fix this file. Planned pieces that aren't built are listed under
"Not built yet" in each section.

DESIGN.md says how things look. This file says what screens exist, what
goes on each one, in what order, and how people move between them. Follow
both. The app on the owner's phone is the reference: if it differs from
this file, update this file.

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

On every tab (DESIGN.md §5)
- Header: the child switcher ("Cal ▾") on the left, the Settings gear on
  the right (Settings opens as a large sheet). Below it the tab name as the
  title: "Today", "Plan", "Progress". Today shows the date under it by day.
- A bottom bar the app draws itself (the system tab bar is hidden): the
  tab pill, and next to it the log control, "Itchy" (one tap) and "•••"
  (a menu: Flare, Bowel movement, Note). Flare and Bowel movement log right
  away; Note opens the note sheet.
- Every tab switches to the night palette from 8 PM to 7 AM.

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
   Asked once a day: on Today (all day, until it's answered), and as an
   evening notification with the four answers as buttons (logs without
   opening the app).
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
1. Header: "Today", the date.
2. Skin today, until answered: "How was Cal's skin today?", "One tap. You
   can change it later.", and four choice cards (Calm, A little itchy,
   Flaring, Very rough). Once answered it collapses to one line under the
   summary card: "Skin today: a little itchy · Change".
3. Summary card "Last night": the rating as the title ("A good night",
   "An okay night", "A rough night", or "Not rated yet"/"Nothing logged"),
   the wake-ups as the caption ("One itchy wake-up, at 2:14 AM"), and the
   sun drawing.
4. Today so far: today's logs, newest first (event, time; "by Dad" with
   more than one caregiver). Tap one to edit or delete it.
5. Logging is the bottom bar's log control.

Night layout (8 PM – 7 AM):
1. Header: "Today", no date.
2. Summary card "So far tonight": "A quiet night" or "2 wake-ups", the
   times, and the moon drawing.
3. A large Itchy button ("Last at 1:52 AM" under it). The log control in
   the bar shows only "•••".
4. Tonight so far.

Not built yet:
- Rating last night from Today (Good / Okay / Rough) when it isn't rated.
- The first-run hint.
- "Add where" after a flare (the body outline).
- Mood, and small sheets for Bowel movement and Mood.
- Swipe to delete in Today so far.
- Asking the skin question only after 4 PM (it shows all day).

## 5. Plan
Job: follow the care plan without thinking about it.

1. Header: "Plan", caption "The routine you set, morning and evening".
2. Summary card "Up next": the routine due now (morning until 2 PM,
   evening after) as the title, "Evening · not done yet" or "Evening ·
   done", "Done 7:40 PM" as the caption, and the sun (morning) or moon
   (evening) drawing.
3. That routine's row: a circle to check, "Evening routine", and the time
   when done. One tap logs it done.
4. The other routine under its own label ("Morning"), the same kind of row.

Not built yet:
- Routine steps (the data exists; there's no screen to add steps, so each
  routine is one row).
- The provider's plan (import is Phase 4), then Supplements, Food
  (Phase 5), and Provider (next visit).

## 6. Progress
Job: show whether things are getting better, and share it.

1. Header: "Progress".
2. Summary card: the week's dates as the eyebrow, the headline as the
   title ("A calmer week", "About the same as last week", …), "Worth
   watching: …" as the caption when something clearly changed, and the
   flower drawing. Compared with this child's own history only.
3. This week: one grid, a column per day: the skin bar on top, the night
   dot below, the day letter underneath (today in indigo). "4 good nights
   of 7" on the right, and a legend: Calm to Very rough, and a dash for
   Not answered.
4. "Share with provider" (opens the doctor report, a PDF) and "Share this
   week's card" (the weekly card as a picture).

Not built yet:
- Week / Month / Since last visit ranges (only this week is shown).
- Itchy wake-ups chart, Photos (Phase 6), day-by-day rows.

## 7. Settings (sheet)
A grouped list, in this order:
1. Children: each child, and "Add a child".
2. Family (when accounts are available): "Share logs with your partner"
   (sign in), or "Household" (members and invites) once signed in.
3. Reminders: Morning check-in, Evening skin check-in, Morning routine,
   Evening routine, each a switch with a time.
4. Quick logging: Home Screen widget, Lock Screen widget, Siri (each opens
   its guide).
5. Account (signed in only): Shown as, Sign out, Delete account.
6. About: "Cali Care organizes the plan your provider gave you. Not
   medical advice." and the version.
7. Debug (debug builds only): Recent logs, Try a notification.

Not built yet:
- The Settings redesign in the new style.
- Your data (export CSV and PDF).
- About: how the app works, privacy, support email.
- Editing a child.
- Control Center and Action Button guides in Quick logging.

## 8. Onboarding (full screen, no account)
On the phone today (the older flow, not yet in the new style):
1. Welcome: the "Cali Care" wordmark over a hairline rule, "A calm place to
   follow your child's care plan and log how their skin and nights are
   going, in one tap.", "No account needed. Everything stays on this
   phone.", and "Add your child".
2. "Who are you caring for?": first name (a nickname is fine), then
   Continue.
3. Quick logging, one part at a time with "Part N of M" and "Skip setup":
   the Home Screen widget, the Lock Screen widget, Siri, the Action Button,
   and (when accounts are available) "Share with your partner". Each has
   Done and Skip.
4. Today.
After the first log, a one-time sheet offers reminders.

Not built yet (designed on the canvas):
- The new onboarding in the app's current style, with real iPhone
  screenshots and the one-step-per-screen setup guide (DESIGN.md §7).
- No reminders sheet after the first log (reminders only in onboarding and
  Settings).

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
- U2. Measures: add skinToday (daily), flare body areas, and routine
  steps (name, morning or evening) to the data model with a schema
  migration and tests; evening skin check-in notification with four
  action buttons.
- U3. Today: day and night layouts exactly as section 4, all states.
- U4. Onboarding: exactly as section 8, with VisualSteps.
- U5. Plan and Progress: as sections 5 and 6 with what exists today.
  Progress becomes the home for Phase 3's reports.
- U6. Review pass: screenshot every screen in every state into
  /design-review/ux/, check against UX.md and DESIGN.md, fix gaps.
