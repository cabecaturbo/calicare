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
   Until the first log ever, one indigo line under it: "Start here: one
   tap for today's skin." (or "Start here: tap Itchy whenever Cal
   scratches." before 4 PM; "Tap Itchy whenever Cal wakes up." at night).
2. Skin today, from 4 PM until answered: "How was Cal's skin today?", "One
   tap. You can change it later.", and four choice cards (Calm, A little
   itchy, Flaring, Very rough). Once answered it collapses to one line
   under the summary card: "Skin today: a little itchy · Change".
3. Summary card "Last night": the rating as the title ("A good night",
   "An okay night", "A rough night", or "Not rated yet"/"Nothing logged"),
   the wake-ups as the caption ("One itchy wake-up, at 2:14 AM"), and the
   sun drawing. Until 7 PM, an unrated night shows "How was the night?"
   and Good / Okay / Rough cards under it; one tap rates it.
4. Today so far: today's logs, newest first (event, time; "by Dad" with
   more than one caregiver). Tap one to edit it; swipe left to delete
   (Delete is ink on oat; Undo in the Logged line).
5. Logging itching is the round Log button in the bottom bar (palm, "Log"),
   on every tab. The "•••" beside "Today so far" has Flare, Bowel
   movement, Mood, and Note. Bowel movement and Mood open a small sheet of
   choices (one tap logs). After a flare, the Logged line offers "Add
   where": a front/back body outline, tap areas, Save. Optional.

Night layout (8 PM – 7 AM):
1. Header: "Today", no date.
2. Summary card "So far tonight": "A quiet night" or "2 wake-ups", the
   times, and the moon drawing.
3. A large Log button (palm, "Log", "Last at 1:52 AM" under it). The round
   Log button stays in the bar too.
4. Tonight so far.

## 5. Plan
Job: follow the care plan without thinking about it.

1. Header: "Plan", caption "The routine you set, morning and evening".
2. Summary card "Up next": the routine due now (morning until 2 PM,
   evening after) as the title ("Evening · 3 steps", "Evening · 2 left",
   "Evening · done", or "Evening · not done yet" with no steps), "Done
   7:40 PM" as the caption, and the sprout (morning) or lamp (evening)
   drawing.
3. That routine's rows: one check row per step (circle, the parent's own
   words, "Done 7:40 PM"). Tap to tick; tap a ticked step to untick (Undo
   in the Logged line). With no steps, one row "Evening routine" logs the
   whole routine.
4. The other routine under its own label ("Morning"), the same rows.
5. "Edit routine" (or "Add steps" with a line explaining it when there are
   none) opens the Routine sheet: Morning and Evening lists, "Add a step"
   at the end of each, tap to rename, swipe left for Pause/Delete (indigo
   and graphite, never red), touch and hold to move. Paused steps stay in
   the editor marked "Paused" and leave Plan. Nothing is suggested.
6. Care plan: "Add your care plan" (with one line saying every item gets
   checked first), then "Finish reviewing your plan" while a draft waits,
   or "About this plan" once it's running (who it's from, when it
   started, every item as written, "Open the original", "End this plan").
   - Add: sign in once (Sign in with Apple), then scan the pages, choose
     a PDF or file, or choose photos. The phone reads the words; only the
     words are sent, and nothing is kept. The file stays on the phone.
   - Review (kept short): "Check what's right. Only checked items are
     kept." Items grouped by kind, each a check, the plan's words, the
     values only ("1/4 tsp · once daily"), and "No dose given, ask at next
     visit" in ochre when a detail is missing. Tap an item to see its
     source line and edit it; press and hold to remove; "Check all".
     "Start plan (N)" keeps only checked items; "Later" keeps the draft;
     "Discard" removes it and the file.

7. A started plan in Plan: its routine and skin steps join the morning and
   evening rows (with the plan's schedule, "3–4x/day", under each);
   "Baths" lists the plan's baths with "1 of 3 this week" (tap to log one;
   rules like "rotate, don't combine" underneath); "Patch tests" shows the
   plan's line, running tests ("Check after Fri 7:11 PM", then "Ready to
   check": tap for No reaction / Some redness / A reaction), and "Start a
   patch test" (what, where, reminder after the plan's wait).

8. Supplements (from a started plan): each supplement with the plan's dose
   and schedule; "Start" (with "Can start after Oct 4" or "Starts 2 weeks
   after … starts" from the plan's rules), then a tap each time it's taken
   ("Taken", "0 of 2 today"); "Rotate after Oct 22" when the plan says;
   press and hold to Stop. The plan's rules sit underneath.

Not built yet:
- The Provider section (4.7); then Food (Phase 5).

## 6. Progress
Job: show whether things are getting better, and share it.

1. Header: "Progress", then a Week / Month switch.
2. Summary card: the week's dates as the eyebrow, the headline as the
   title ("A calmer week", "About the same as last week", …), "Worth
   watching: …" as the caption when something clearly changed, and the
   flower drawing. Compared with this child's own history only.
3. This week: one grid, a column per day: the skin bar on top, the night
   dot below, the day letter underneath (today in indigo). "4 good nights
   of 7" on the right, and a legend: Calm to Very rough, and a dash for
   Not answered.
4. "Share with provider" (opens the doctor report, a PDF, starting at the
   dates on screen), "Caregiver card", and, on Week, "Share this week's
   card" (the weekly card as a picture).
5. Caregiver card (sheet): the parent's own words for a sitter or
   grandparent: bedtime routine (starts from Plan's evening steps), safe
   snacks, please avoid, "If Cal is scratching", and contacts. A live
   preview of the card ("Looking after Cal", empty sections left off,
   "Not medical advice" at the foot); Share picture and Share PDF. Saved
   per child on this phone.

Month: the same summary card ("September 2026", "A calmer month", "About
the same as last month", …, compared with last month by averages, so a
partial month is fair) and a calendar grid: weekday letters, then each
day's number (today in indigo), skin square, and night dot; dashes for not
answered. "9 good nights of 28" on the right.

Not built yet:
- "Since visit" (once visits exist, Phase 4).
- Itchy wake-ups chart, Photos (Phase 6), day-by-day rows.

## 7. Settings (sheet)
A grouped list, in this order:
1. Children: each child (opens their page: name, birth date, color, Save;
   "Remove Cal" when there's more than one child and the family isn't
   shared), and "Add a child".
2. Family (when accounts are available): "Share logs with your partner"
   (sign in), or "Household" (members and invites) once signed in.
3. Reminders: Morning check-in, Evening skin check-in, Morning routine,
   Evening routine, each a switch with a time.
4. Quick logging: Home Screen widget, Lock Screen widget, Control Center
   (each opens the full-screen setup guide), Siri, and "Send the weekly
   card automatically" (four numbered steps for a Shortcuts automation
   with "Get Weekly Card", and Apple's Shortcuts button).
5. Your data: "Export and what's stored where": every log as a
   spreadsheet (CSV, one row per log), the care log PDF for any dates, and
   what's stored on the phone, what's shared with family, and that photos
   never leave the phone.
6. Account (signed in only): Shown as, Sign out, Delete account.
7. About: "How Cali Care works" (what each log means, how Progress
   compares, the 7 PM day), Version, and "Not medical advice" under it.
8. Debug (debug builds only): Recent logs, Try a notification.

Not built yet:
- A support email and the privacy policy link in About (the policy comes
  with the landing page, Phase 7).
- Removing a child in a shared family (needs the owner check).
- The Action Button guide (until it's recorded on a real iPhone).

## 8. Onboarding (full screen, no account)
1. Welcome: the "Cali Care" wordmark over a hairline rule, the sunrise
   drawing, "A calm place to follow your child's care plan and log how
   their skin and nights are going, in one tap.", "Add your child", and
   "No ads. Photos never leave your phone." under it.
2. "Who are we looking after?": first name (focused), birth date and
   color optional, Continue. Going back and forward edits the same child.
3. "Gentle reminders": Morning check-in and Evening skin check-in, each a
   switch with a time. The first switch shows one line ("Your iPhone will
   ask once…"), then the system prompt. "Skip for now" until one is on,
   then Continue.
4. "Log from anywhere": Home / Lock / Control Center, each showing a real
   screenshot of the finished setup; "Show me how" opens that guide;
   "Skip for now" (or "Go to Today" after a guide).
5. Today.
Steps 2–4 have a back button and a thin three-part progress line.
Someone who left after adding a child picks up at step 3.

The setup guide (from onboarding and Settings): full screen, the guide's
name and a close button, a progress line, one real iOS 27 screenshot per
step with the tap spot ringed and a zoomed circle of it, one sentence,
Back and Next, then "You're set." over the finished screen, and Done.
Home Screen widget (6 steps), Lock Screen widget (6), Control Center (5).

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
