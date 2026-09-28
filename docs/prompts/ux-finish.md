# Finish the UX rebuild

Goal: everything in the "Not built yet" lists of UX.md, in the style on the
owner's phone (DESIGN.md and UX.md describe it). Nothing already on the phone
changes look unless a step says so.

Rules for every step: match the existing screens (the header, summary
cards, choice cards, bottom bar, 12pt corners, SF body with Newsreader
titles); night palette 8 PM – 7 AM; VoiceOver labels; 44pt targets;
Dynamic Type; no placeholders for unbuilt features.

---

## UX.1 Today: the missing pieces
1. Rate last night from Today: when last night has no rating, the Last
   night card offers Good / Okay / Rough as three choice cards (the same
   style as the skin check-in); one tap logs it. At night, rating tonight
   isn't offered.
2. First-run hint: until the first log, one line under the header in
   indigo: "Start here: one tap for today's skin." (by day) or "Tap Itchy
   whenever Cal wakes up." (at night). Gone after the first log.
3. "Add where" after a flare: the "Logged" line for a flare adds "Add
   where", which opens a sheet with a simple front/back body outline; tap
   areas (BodyArea), Save. Optional, never required. Uses
   `LogStore.setBodyAreas`.
4. More menu: add Mood. Bowel movement and Mood open a small sheet with
   their choices as rows (one tap logs); Flare and Note stay as they are.
5. Swipe to delete in Today so far (soft delete, with Undo in the Logged
   line). Tap still edits.
6. Ask the skin question after 4 PM only (before that, Today starts with
   the Last night card). Keep "Change" once answered.
7. Remove the one-time reminders sheet after the first log (reminders live
   in onboarding and Settings).
Done when: builds clean, tests pass (unit tests for the 4 PM rule and the
first-run rule), and each piece is screenshotted day and night.

---

## UX.2 New onboarding and the setup guides
1. Onboarding in the phone's style, full screen, no account:
   Welcome → Your child → Reminders → Log from anywhere → Today.
   - Welcome: the wordmark, the sunrise drawing, one sentence, "Add your
     child", the trust line "No ads. Photos never leave your phone."
   - Your child: "Who are we looking after?", a real "First name" field
     (autofocus), birthday optional.
   - Reminders: the morning check-in and the evening skin check-in with
     switches and times; turning one on shows one priming line, then the
     system prompt. Skip is always there.
   - Log from anywhere: a real iPhone screenshot of the Home Screen with
     the widget; a switch for Home Screen / Lock Screen / Control Center;
     "Show me how" and "Skip for now". The Action Button is optional.
   - A thin progress line and a back button on steps after Welcome.
2. The setup guide: one step per screen with the real iOS 27 screenshots
   in design/screenshots/guide (a ring and tap marker on the spot, a
   zoomed callout, one sans sentence, Back and Next, "Done" at the end).
   Paths: Home Screen widget (4 steps), Lock Screen widget (3), Control
   Center (3), Action Button (only once real recordings exist; hidden
   until then).
3. Settings › Quick logging opens the same guides.
4. Screenshots as app assets named by feature and iOS version.
Done when: a fresh install reaches the first widget log in under a
minute; onboarding and every guide screen are screenshotted day and
night; builds clean; tests pass.

---

## UX.3 Routine steps in Plan
1. "Edit routine" in Plan: add, rename, reorder, pause, and delete steps
   for morning and evening (RoutineStore). Steps are whatever the parent
   types; nothing is suggested.
2. Plan shows the steps as check rows under "Up next"; checking one logs
   it through `LogStore.logRoutineStep`. With no steps, the routine stays
   one row as today.
3. The Up next card counts what's left ("Evening · 2 left").
4. Steps sync (already in the data model).
Done when: steps can be set up and checked off, sync between phones in
tests, builds clean, tests pass.

---

## UX.4 Progress ranges
1. A segmented control under the header: Week / Month / Since visit.
   "Since visit" shows once a visit date exists (Phase 4 adds visits; until
   then only Week and Month).
2. Month: the same summary card (headline for the month vs the month
   before) and a month grid (skin and night by day, 4–5 rows).
3. Share with provider uses the chosen range for the doctor report.
4. Pure logic in Core for month summaries, with tests (month boundaries,
   partial months, time zones).
Done when: Week and Month both work with real data, builds clean, tests
pass.

---

## UX.5 Settings, finished
1. Settings in the phone's style (sections, rows, 12pt corners), keeping
   today's order.
2. Children: tap a child to edit name, birthday, and color; remove a child
   (owners only when shared).
3. Your data: export everything as CSV (every log, with child, time,
   value, note, source, logged by) and as the doctor PDF for any range;
   "What's stored where" in plain words.
4. About: how the app works (what each measure means, in plain words),
   privacy (link to the policy once it exists), "Not medical advice",
   version, support email.
5. Quick logging: Home Screen widget, Lock Screen widget, Control Center,
   Siri (and the Action Button once recorded).
Done when: export opens in Numbers and Files, every Settings screen is
screenshotted day and night, builds clean, tests pass.

---

## UX.6 Review pass
1. Screenshot every screen in every state (first run, normal, lots of
   data, two children, long names, night, largest Dynamic Type, offline)
   into design-review/ux/.
2. Check each against DESIGN.md and UX.md and the list in DESIGN.md §2;
   fix gaps.
3. Update DESIGN.md and UX.md if the phone and docs differ (the phone
   wins).
Done when: the owner has tried it on the phone and said it's good.
