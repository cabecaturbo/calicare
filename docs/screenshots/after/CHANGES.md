# Hierarchy and step wording: what changed

Before: `docs/screenshots/before/`. After: this folder. Shots are half-size JPEGs. `-day` is the default text size; `-xxxl` is the largest accessibility size. Both come from the `LEGACYPLAN` seed, a made-up plan with the same shapes as the real import.

## Every screen
- Section headers are Newsreader 20/26 (title3), not small bold sans.
- Four text levels: screen title, section header, row, meta.
- Spacing is 4/8/16/24/40: sections 40 apart, headers 8 above their rows.
- A paper strip sits behind the status bar, so nothing scrolls under the clock.
- Sheet and pushed-screen headers are solid.

## Plan (`plan-*`)
- "Up next" stays the one focal point. It counts only steps to tick, so notes no longer count.
- **Step labels:** each label starts with a verb, is 6 words or fewer, and has no "Step 1:". The plan's detail sits on one meta line under it. Names are no longer cut off mid-word.
- **Skin group:** consecutive Apply steps sit under "Skin", with a "3-4x per day" badge, numbered 1, 2, 3.
- **Notes aren't steps:** "Support the skin 3-4x per day" and "Continue … 60-90 days" are no longer checkable.
- **Tapping:** the check circle is its own 44pt target. Tapping the words shows the plan's full line and lets you rename the step.
- **"Edit routine"** moved up, right under the routines.
- **Supplements:**
  - "ADD" shows as a "New" pill.
  - "Continue Vitamin D, Fish Oil" shows as two rows.
  - Each row has one meta line, and the directions are behind "How to give".
  - Every row has the same pill on the right: "Start", then "0 of 2 today".
  - "Consider adding…" and "…may be indicated" lines sit under "Your provider mentioned", with no actions.
- **Large text:** names, status pills and counts stack instead of breaking words.

## Edit routine (`edit-routine-*`)
- Headers read "Morning" and "Evening" (no longer all caps).
- Each step shows its category symbol, its label, and the original words when they add something.
- Notes are marked "Note · not ticked off".
- Tapping a step opens "From your plan" with the full original words and "Name on Plan".

## Food list (`food-list-*`)
- The focal point is "6 safe foods", with "1 testing · 1 paused" under it.
- "Your plan says to avoid" lists one thing per line. "As much as possible · Buy organic when able" is a meta note.
- **Large text:** the "You · Oct 2" date moves under the food's name.

## Patch tests (`patch-test-start-*`)
- The sheet has "What" and "Where" headers and body-size text.
- It opens at half height and can be dragged to full height, so large text doesn't clip.

## Add a visit (`add-visit-*`)
- The sheet has "When", "Who" and "Note" headers.
- It has the same half or full height as the patch test sheet.

## Today, Progress, Settings
- Serif section headers and the new spacing only. Layout is unchanged.
