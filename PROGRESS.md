# PROGRESS

Claude Code: do the first unchecked prompt only, then stop.
See docs/prompts/README.md for the rules.

## Phase 1: One-tap logging (docs/04-build-plan.md)
- [x] 1.1 Project scaffold
- [x] 1.2 Data model and local storage
- [x] 1.3 App Intents
- [x] 1.4 Interactive widgets
- [x] 1.5 Notification buttons
- [x] 1.6 Onboarding and Today screen
- [x] 1.7 🛑 MANUAL: family test for a few days. Human writes notes in
      docs/family-test-notes.md, then checks this box.
      Skipped by the owner on Sep 26, 2026 to start Phase 2; no family-test-notes.md yet.

## Phase 2: Sync and caregivers (docs/prompts/phase-2-sync.md)
- [x] 2.1 Supabase schema and RLS (skip if already done; verify first)
      Households, members, children, log_events with RLS; 19 pgTAP tests pass locally; applied to the real project. See supabase/README.md.
- [x] 2.2 🛑 Sign in with Apple (optional account)
      Native Sign in with Apple via Supabase; Settings → Account and an optional last onboarding step. Owner confirmed sign in/out on the iPhone 15 Pro.
- [x] 2.3 Background sync engine
      Push/pull with last-write-wins, soft deletes, first-sign-in upload; syncs on open, 3 s after changes, and in the background. Verified on the iPhone both ways.
- [ ] 2.4 Households and caregiver invites
      Code merged: invite and join by code, members list, 16 SQL tests. Still to do: the two-phone test (a second account joins and sees the same logs).
- [ ] 2.5 "Logged by" names
      Code merged: logs save your name ("You" signed out); "by Dad" on the timeline and small widget when 2+ people share. Still to do: check names on two phones.
      Code merged: logs save your name ("You" signed out); "by Dad" on the timeline and small widget when 2+ people share. Still to do: check names on two phones.
- [x] 2.6 Account settings and account deletion
      Delete account with the last-owner rule (Edge Function + SQL). Verified on the iPhone: nothing left in Supabase afterwards. Left over: Apple token revocation before App Store review.

## Phase 3: Report cards (docs/prompts/phase-3-reports.md)
- [x] 3.1 Weekly stats engine
      WeeklyReport in Core: nights, wake-ups vs last week, routines, skin by day, bowel movements, mood, headline, one worth-watching line. 12 tests.
- [x] 3.2 Weekly report card image and share sheet
      WeeklyCardView per DESIGN.md §10, rendered at 3x; Today → Share this week. Verified sharing to Messages and Mail on the iPhone.
- [x] 3.3 🛑 iMessage extension
      Messages extension with a compact bubble; the full card opens from the message link. Verified sending on the iPhone.
- [ ] 3.4 Doctor PDF
      Code done: multi-page PDF with summary, charts, day by day, notes, full log; share and email. Waiting on a device check in Files and Mail.

⏸ Phase 3 is paused here (Sep 27, 2026) for the UX rebuild below.

## UX rebuild (UX.md section 12), before the rest of Phase 3
One prompt per session, same rules as docs/prompts/README.md.
- [ ] U1 App shell: three tabs, headers, Settings sheet on every tab, quick
      log bar on Plan and Progress, navigation rules.
- [ ] U2 Measures: add skinToday (daily) and flare body areas to the data
      model with a schema migration and tests; evening skin check-in
      notification with four action buttons.
- [ ] U3 Today: day and night layouts exactly as UX.md section 4, all states.
- [ ] U4 Onboarding: exactly as UX.md section 8, with VisualSteps.
- [ ] U5 Plan and Progress: as UX.md sections 5 and 6 with what exists today.
      Progress becomes the home for Phase 3's reports.
- [ ] U6 Review pass: screenshot every screen in every state into
      /design-review/ux/, check against UX.md and DESIGN.md, fix gaps.

## Phase 3, continued (after the UX rebuild)
- [ ] 3.5 Caregiver card
      Note: reports live in the Progress tab (UX.md section 6) and follow DESIGN.md section 10. Skin by day comes from the skinToday measure.
- [ ] 3.6 Scheduled sends via Shortcuts
      Note: reports live in the Progress tab (UX.md section 6) and follow DESIGN.md section 10. Skin by day comes from the skinToday measure.

## Phase 4: Care plans (docs/prompts/phase-4-care-plans.md)
- [ ] 4.1 Care plan data model
- [ ] 4.2 🛑 Parse-care-plan Edge Function
- [ ] 4.3 Import and review flow
- [ ] 4.4 Routine, topical steps, baths, patch tests
- [ ] 4.5 Supplement ramp-up scheduler
- [ ] 4.6 "Worse since when?" timeline
- [ ] 4.7 Provider tracker and journal export

## Phase 5: Food (docs/prompts/phase-5-food.md)
- [ ] 5.1 Food list and food families
- [ ] 5.2 Food trials and reintroduction
- [ ] 5.3 Rotation planner and plant counter
- [ ] 5.4 🛑 "What can I make" (AI)
- [ ] 5.5 Leftovers and freezer timers
- [ ] 5.6 Food-to-skin timeline and nutrient coverage

## Phase 6: Photos, products, home (docs/prompts/phase-6-photos-products-home.md)
- [ ] 6.1 On-device photo timeline with ghost overlay
- [ ] 6.2 Product diary
- [ ] 6.3 Restock reminders and labeled affiliate links
- [ ] 6.4 Home checklist
- [ ] 6.5 Rx, prior-auth, copay reminders and insurance history report

## Phase 7: Launch (docs/prompts/phase-7-launch.md)
- [ ] 7.1 🛑 Apple Watch app
- [ ] 7.2 Keyboard extension
- [ ] 7.3 🛑 Premium paywall
- [ ] 7.4 Monthly recap
- [ ] 7.5 🛑 Vercel landing page and privacy policy
- [ ] 7.6 🛑 Launch readiness and TestFlight
