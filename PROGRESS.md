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
- [ ] 1.7 🛑 MANUAL: family test for a few days. Human writes notes in
      docs/family-test-notes.md, then checks this box.

## Phase 2: Sync and caregivers (docs/prompts/phase-2-sync.md)
- [ ] 2.1 Supabase schema and RLS (skip if already done; verify first)
- [ ] 2.2 🛑 Sign in with Apple (optional account)
- [ ] 2.3 Background sync engine
- [ ] 2.4 Households and caregiver invites
- [ ] 2.5 "Logged by" names
- [ ] 2.6 Account settings and account deletion

## Phase 3: Report cards (docs/prompts/phase-3-reports.md)
- [ ] 3.1 Weekly stats engine
- [ ] 3.2 Weekly report card image and share sheet
- [ ] 3.3 🛑 iMessage extension
- [ ] 3.4 Doctor PDF
- [ ] 3.5 Caregiver card
- [ ] 3.6 Scheduled sends via Shortcuts

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
