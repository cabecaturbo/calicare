# Phase 5: Food

Goal: help the family run the food side of their own plan and help the
safe food list grow. The app never tells a parent to remove or add a
food; it tracks what the plan or the parent decides.

Rules (autopilot.md, Part 3): no recommendations; "worth watching"
wording only (never "cause", "trigger", "likely"); nutrient coverage says
what may be less covered and suggests asking the provider or a dietitian.
Screens in the phone's style.

---

## 5.1 Food list and food families
1. Foods with a status the parent sets: safe, testing, paused (with the
   date and who decided: plan or parent).
2. A built-in food family table (for rotation), editable.
3. A Food section in Plan (hidden until used). Sync and SchemaV4.
Done when: foods can be added and moved between statuses; tests pass.

---

## 5.2 Food trials and reintroduction
1. Start a trial for a paused or new food: the plan's or parent's
   schedule (dose steps, days), reminders, and a one-tap "reaction worth
   watching" log.
2. Reactions can show up 12–24 hours later: the trial view shows skin and
   nights across the following days.
3. Ending a trial: the parent chooses safe, keep testing, or paused.
Done when: a full trial runs on the phone; tests cover the schedule.

---

## 5.3 Rotation planner and plant counter
1. A rotation planner by food family, following the plan's rotation (for
   example 4 days); it only arranges foods already on the safe list.
2. A weekly plant diversity counter (the plan's goal if it states one,
   e.g. 40–50). No streaks.
Done when: a week plans correctly in tests; the counter updates from
logged meals.

---

## 5.4 🛑 "What can I make" (AI)
Manual: confirm the Claude API key secret exists (from 4.2).
1. Edge Function `meal-ideas`: given what's in the fridge and the safe
   list, returns simple meal ideas.
2. Code rejects any recipe containing a paused or avoided food, before
   anything reaches the phone.
3. Leftovers: ideas note that fresh is lower in histamine than leftovers
   or aged foods (from the research notes), without advising.
4. Free vs premium follows 7.3.
Done when: paused foods never appear in tests (fuzzed); ideas show on the
phone.

---

## 5.5 Leftovers and freezer timers
1. Log a cooked batch; timers for fridge and freezer as the parent sets
   them; reminders to use or freeze.
Done when: timers and reminders work on the phone.

---

## 5.6 Food-to-skin timeline and nutrient coverage
1. Food changes join the "Worse since when?" timeline (4.6), with the
   12–24 hour delay shown.
2. Nutrient coverage: when food groups are paused, list what may be less
   covered, and suggest asking the provider or a dietitian. Never a
   supplement.
Done when: tests cover both; wording reviewed against the rules.
