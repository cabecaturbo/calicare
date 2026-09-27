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

On every tab (DESIGN.md §5)
- AppHeader: the child switcher ("Cal ▾", label size) on the left, the
  Settings gear on the right (Settings opens as a sheet). Below it the
  screen title in display, matching the tab name: "Today", "Plan",
  "Progress". Optional caption (Today: the date).
- One log control, docked right of the tab bar on every tab: "Itchy"
  (one tap) and "More" (Flare, Bowel movement, Note). Same options day
  and night. It replaces Today's old Log section and the quick log bar.
  In the app: the tab bar accessory on iOS 26.1+, an inset bar before.
- Every tab has a night version (8 PM – 7 AM): the same layout in the
  night palette.

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
1. AppHeader: "Today", the date as caption.
2. Skin today, until answered: "How was Cal's skin today?" (title) and
   four card buttons (Calm, A little itchy, Flaring, Very rough). This is
   the primary element; nothing else on the screen is louder. Once
   answered it collapses to one line under the summary card: "Skin
   today: A little itchy · Change".
3. Summary card "Last night": "A good night", "One itchy wake-up, at
   2:14 AM", sun drawing. If the night isn't rated, the card asks "How
   was last night?" with Good, Okay, Rough.
4. Today so far: the timeline (event, time; "by Dad" with more than one
   caregiver). Swipe to delete, tap to edit.
5. Logging is the docked log control. Flare logs instantly; the
   confirmation line adds "Add where" (body outline, optional). Bowel
   movement opens a small sheet; Note opens a text sheet.

Night layout (8 PM – 7 AM):
1. AppHeader: "Today", no caption.
2. Summary card "So far tonight": "Two wake-ups", the times, moon drawing.
3. A large full-width "Itchy" button (title size, about 96pt, accent
   fill). The docked log control shows only "More" on this screen.
4. Tonight so far.
Nothing else.

First run: a one-line hint under the header: "Tap Itchy whenever it
happens. That's all it takes." Gone after the first log.

## 5. Plan
Job: follow the care plan without thinking about it.

1. AppHeader: "Plan", caption "The routine you set, morning and evening".
2. Summary card "Up next": "Evening · 3 left", moon drawing (sun in the
   morning). Then that routine's steps as check rows. A step from the
   provider's plan shows its name and dose, with "From Dr. [name]'s
   plan" as a caption.
3. The other routine (e.g. Morning, "Done 7:40 AM"), then "Edit routine".
4. From your provider: one "Provider's plan" row (provider, date) that
   opens the full plan. It appears once a plan has been imported
   (Phase 4); until then the section is absent.

After import (Phase 4+), more sections in this order, each hidden if
empty: Supplements (active, what starts next and when), Food (Phase 5),
Provider (next visit, messages left).

## 6. Progress
Job: show whether things are getting better, and share it.

1. AppHeader: "Progress".
2. Segmented control: Week / Month / Since visit (Since visit once a
   visit date exists; doctors think in visits).
3. Summary card: the headline ("Calmer than last week") with at most one
   "worth watching" line as its caption. Flower drawing. Compared with
   this child's own history only.
4. This week: one aligned grid, a column per day: the skin bar on top,
   the night dot below, the day letter underneath (today in accent). A
   small legend: calm → very rough, dashed outline = not answered.
5. Share with provider: one secondary button (doctor report; the weekly
   card for family is in its share sheet).
6. Later: itchy wake-ups chart, Photos (Phase 6), day rows (tap → that
   day's timeline).

Fewer than 3 days of logs: the grid is replaced by one sentence: "After a
few days of logging, you'll see how things are going here." Share stays.

## 7. Settings (sheet)
Grouped List:
1. Children
2. Family: sign in, members, invite (Phase 2)
3. Reminders: morning check-in, skin check-in, routine reminders
4. Quick logging: Home Screen widget, Lock Screen widget, Control
   Center, Action Button, Siri. The first three open the same setup
   guides as onboarding. This is the home for
   every guide except onboarding's Home Screen widget. A guide or step
   without a real screenshot or recording is hidden, never shown as a
   placeholder.
5. Your data: export everything (CSV and PDF), what's stored where
6. Account: display name, sign out, delete account
7. About: how the app works (what each measure means, in plain words),
   privacy, "Not medical advice," version, support email
Debug list: debug builds only.

## 8. Onboarding (full screen, no account)
Install to first log in under 60 seconds when optional steps are skipped.
One idea per screen: a large visual (a hand-drawn drawing or a phone
showing the real thing), a heading in title, body in sans, one primary
button. Steps 2–5 have a back button and a progress bar in equal steps
(25 / 50 / 75 / 100%).
1. Welcome: wordmark, a sunrise drawing, the headline in display ("Your
   child's skin, kept in one calm place."), one sentence, "Add your
   child", and the trust line "No ads. Photos never leave your phone."
   ("Not medical advice" lives in Settings > About.)
2. Your child: "Who are we looking after?", a real text field labelled
   "First name" (autofocus, display size). Birthday later.
3. The one scale: "How was Cal's skin today?" with the four answers
   rising as bars; "Lighter is calmer", "One tap".
4. Log from anywhere (step 3 of 4): a realistic iPhone showing the small
   widget, looping tap → "Logged" → normal. "Log at 2 AM without opening
   anything", one sentence, and a switch under the phone: Home Screen /
   Lock Screen / Control Center (the phone follows it). "Show me how"
   opens the setup guide for the chosen surface (DESIGN.md §7: 4 steps
   for the Home Screen, 3 each for the Lock Screen and Control Center,
   then "You're set."); "Skip for now".
5. Evening check-in: a locked phone at 6:30 PM with the four answers on
   the notification. "Turn on reminders" turns on the evening skin
   check-in (with a short priming line, then the system prompt); "Not
   now". Then land on Today.
No sign-in step, no account, paywall, or survey in onboarding.

Reminders live in two places only: onboarding step 5 and Settings >
Reminders. No reminders sheet or prompt after the first log.

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
