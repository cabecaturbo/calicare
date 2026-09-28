# Phase 4: Care plans

Goal: the family's own plan (from any provider, conventional or natural)
lives in the app, confirmed by the parent, and runs itself.

Rules for the whole phase (autopilot.md, Part 3):
- The AI only extracts what the provider wrote. It never guesses or adds
  doses, foods, or timing. Blanks are flagged: "Your provider left this
  blank. Worth asking at your next visit."
- Nothing goes live until the parent confirms it. Every item shows where
  it came from (the page and the line of the original).
- The server parses the file and keeps nothing but the confirmed items.
  The original file stays on the phone.
- The app never recommends a treatment. Screens are in the phone's style.

---

## 4.1 Care plan data model
1. SwiftData models (SchemaV3 with a migration): CarePlan (provider,
   date, source file reference on the phone, status draft / active /
   ended), PlanItem (kind: routine step, topical step, bath, supplement,
   medication, food rule, fundamental, follow-up; text as written; dose,
   frequency, timing, duration fields only when the plan states them;
   source page and line; confirmed flag), Visit (date, provider, notes).
2. Supabase tables and RLS for the confirmed items and visits only (never
   the file), plus sync.
3. Tests: migration from V2, sync, confirmed-only upload.
Done when: builds clean, tests pass, the migration is applied to Supabase.

---

## 4.2 🛑 Parse-care-plan Edge Function
Manual: the Claude API key as a Supabase secret (list the exact steps,
then stop until the owner says done).
1. Edge Function `parse-care-plan`: receives text extracted on the phone
   (Vision OCR for photos, PDFKit for PDFs), never the file itself.
2. Calls Claude with a strict extraction prompt and a JSON schema; every
   item carries the exact source text; missing values become explicit
   blanks, never guesses.
3. Validates the JSON in code; rejects any field not grounded in the
   source text.
4. Keeps nothing after responding. Rate limited per account.
5. Tests with the anonymized example plan in docs/02-research-notes.md.
Done when: the example plan parses with every item traced to its source
and blanks flagged; nothing stored server-side.

---

## 4.3 Import and review flow
1. Plan › "Add your care plan": import a PDF or photo (camera, Files,
   Photos). The file stays on the phone.
2. Review screen: every item as a row with its source line; edit, remove,
   or confirm each; blanks shown with "Your provider left this blank.
   Worth asking at your next visit."
3. Nothing is active until the parent taps "Start this plan".
4. The original file opens from About this plan.
Done when: the example plan imports, reviews, and starts on the owner's
phone.

---

## 4.4 Routine, topical steps, baths, patch tests
1. Confirmed routine and topical steps become Plan's routine steps
   (UX.3), with times per day as written.
2. Bath rotation: whichever baths the plan lists, rotated as it says
   ("don't combine" respected); today's bath shown in Plan.
3. Patch-test timer: start a test on a spot, check-in reminders at the
   plan's intervals, log the result.
4. Plan shows "Today's steps", then the sections in UX.md §5 order.
Done when: a started plan drives Plan's checklist for a full day on the
phone; tests pass.

---

## 4.5 Supplement ramp-up scheduler
1. Only supplements the plan lists, with the plan's own rules ("one at a
   time", "3–5 days apart", "start with a drop", "start X two weeks after
   Y", rotate after N weeks).
2. The scheduler proposes start dates from those rules; the parent
   confirms each. Missing rules stay blank and are flagged, never filled.
3. Reminders at the plan's times; split doses; reassess reminders.
4. Plan shows what's active, what starts next and when.
Done when: the example plan's supplements schedule correctly in tests and
on the phone.

---

## 4.6 "Worse since when?" timeline
1. A timeline in Progress of changes (plan items started or stopped,
   supplements, products, food changes later) next to skin and nights.
2. When skin or nights get worse, "Worse since when?" shows what changed
   in the days before. Wording notices, never explains: never "cause",
   "trigger", or "likely".
Done when: tests cover the change detection; it reads correctly on the
phone.

---

## 4.7 Provider tracker and journal export
1. Provider section in Plan: next visit, messages left of the plan's
   allowance (e.g. 5 in 8 weeks), follow-up reminders.
2. Visits feed Progress's "Since visit" range (UX.4).
3. Journal export in the provider's format (daily changes, rash and itch,
   bowel movements, sleep, mood), as PDF and CSV, ending with "Not
   medical advice".
Done when: export matches the example plan's tracking format; tests
pass.
