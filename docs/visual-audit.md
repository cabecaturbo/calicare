# Visual audit (October 11, 2026)

Before and after captures of every screen, day and night, on iPhone SE (3rd gen) and iPhone 17 Pro Max, at default text and the largest accessibility size (AX5). The status bar is 9:41 with a full battery.

- **Before:** `screenshots/audit/2026-10-11-before/`
- **After:** `screenshots/audit/2026-10-11-after/`
- **File names:** `<screen>-<day|night>-<se|max>-<default|ax5>.png`. Long screens are numbered by scroll position (`plan-day-3-…`). Both folders are local only (gitignored, about 1 GB). The before/after page is linked in the PR.
- **Re-run:** `scripts/audit-capture.sh screenshots/audit/<date>` (about 4 hours for both phones).
- **Branches:** four stacked PRs, none merged.
  - Blockers: `audit/blockers`
  - Polish: `audit/polish`
  - Share outputs: `audit/share`
  - Release checks: `audit/release`

## Step 1: capture
- [x] **Onboarding 1–5 and all three step-5 tabs:** `onb-*`
- [x] **Today:**
  - first run: `today-first-run-*`, `onb-6-today-*`
  - after logs: `today-*`, `today-unrated-*`
  - night: the `night` variants
- [x] **The Log flow:**
  - tap Log: `log-banner-*`, `bar-logged-*`
  - More to log: `log-more-*`, `bar-more-*`
  - Undo: `log-undone-*`
- [x] **To do:**
  - morning, afternoon, bedtime: `todo-morning-*`, `todo-afternoon-*`, `todo-bedtime-*`
  - all done: `todo-alldone-*`
  - a step's page: `todo-item-*`, `todo-skin-sheet-*`
- [x] **Progress:**
  - Week, Month: `progress-week-*`, `progress-month-*`
  - Since visit: `progress-since-visit-*`
  - empty: `progress-empty-*`
- [x] **Plan:**
  - the week card, Coming up, supplements: `plan-length-*`, `plan-*`
  - item page: `item-*`
  - full plan viewer: `plan-full-*`
  - Coming up › See all: `plan-coming-up-*`, when the seed has enough to show it
  - plan-import review: `careplan-review-*`
- [x] **Settings, including Widgets and Siri:**
  - `settings-*`
  - the guides opened from Settings: `settings-guide-lock-*`, `settings-guide-cc-*`
  - `settings-siri-*`
- [x] **All three setup guides, every step:** `guide-lock-*`, `guide-home-*`, `guide-cc-*`
- [x] **Widgets** (small, medium, Lock Screen, Control Center) in default, clear and tinted looks: `design/screenshots/looks/`
- [ ] **Notifications.** Not captured. The simulator doesn't show our permission prompt under UI tests, so nothing can be delivered. The wording is in `Core/Reminders/ReminderCopy.swift`, unchanged apart from the Lock Screen reminder.
- [x] **The weekly card image, the doctor PDF and the caregiver card:** `design-review/audit-share/`
- [x] **Error states:**
  - plan import with no internet: `plan-import-offline-*`
  - notifications denied in onboarding: night run of `onb-4-reminders-on-*`
  - notifications denied in Settings: `settings-reminders-off-*`

## Step 2: fixes

### Blockers (`audit/blockers`)
1. [x] **"Your child" with the keyboard up.**
   - Onboarding pages scroll above the keyboard, and dragging puts it away.
   - Rows fade softly under the pinned Continue instead of being sliced.
   - On SE the keyboard leaves room for one row, so the Color row is reached by scrolling.
   - Before: `onb-2-child-day-se-default.png`. After: same name in the after folder.
2. [x] **One night boundary, 7 PM–7 AM.**
   - Night colors, the night layout, the care day and the list labels all switch at 7 PM.
   - By day, Today lists "Today" (since 7 AM), then "Last night". At night it lists "Tonight".
   - Night colors now come on an hour earlier than before (they started at 8 PM).
   - Before/after: `today-*`, `today-unrated-*`.
3. [x] **Zoom circles removed.**
   - Each step has one ring on the real target.
   - Control Center step 5 now has a ring on an empty slot, where the test taps.
   - Corners read "top left corner" and "top right corner".
   - Before/after: `guide-*`.
4. [~] **Guides recaptured in one run, all on Sun Oct 11.**
   - Control Center no longer shows "Mon 28".
   - The Lock Screen clock can't be frozen, so times differ by a few minutes.
   - **Not fixed:** Home step 3 still shows a keyboard. On iOS 27, Edit opens this menu with the keyboard up, so no capture timing avoids it.
5. [x] **Tab bar.**
   - A paper fade sits behind the floating glass bar, so rows don't show through.
   - Every tab already had a 120pt bottom inset.
   - Before/after: `plan-day-*`, `todo-*`.

### Polish (`audit/polish`)
6. [x] **One header:** To do now matches Today, Progress and Plan (Cal and the gear above the title), and keeps its why-line.
7. [x] **Buttons:** every button label is SF semibold 17 (`TypeStyle.button`), including the outlined ones.
8. [x] **Today at night:** the Quick Log row sits under the big Log card.
9. [x] **Switches:** the off track is #8F7F6D by day and #7A6A5A at night (3.4:1 on paper). On is the accent.
10. [x] **Color dots:**
    - 24pt dots in 44pt targets.
    - The chosen dot gets a 2pt ink ring, and VoiceOver hears "Chosen".
    - Every dot has a 1pt graphite border, so oat shows.
11. [x] **Supplement tiles:** "Dose: see the label." I didn't use "You added this" because every plan item comes from the imported plan; the app has no parent-added items, so that line would be untrue.
12. [x] **Dashes and corners:** "3–4" with an en dash in the skin count. The guides say "top left corner" and "top right corner". The provider's own words are shown as written.
13. [x] **"Full plan":** accent, semibold, with a chevron.
14. [x] **Guide pictures at night:** dimmed 15%.
15. [x] **Step 5, Lock Screen tab:** cropped close around the Log widget, so it reads.
16. [x] **VoiceOver:**
    - The "…" buttons already say "More to log".
    - Apple's accessibility audit (`AccessibilityAuditTests`) found no unlabeled controls of ours. The three blank ones it reports are the keyboard's suggestion slots.
17. [x] **Two captures:**
    - The color-row capture now drags the keyboard away.
    - "Remind me later" shows the time: "We'll remind you at 8:42 PM." In the night run (notifications denied), it says so instead.
18. [x] **Demo data:** the demo plan uses plain product names (Omega-3 Skin Drops, Probiotic Gut Powder, Calendula Herbal Drops, Vitamin D3 drops…) instead of "Brand D/F". No real trademarks.

### Share outputs (`audit/share`)
- [x] **A. Weekly card:**
  - Day tokens, the olive scale, and 2pt #67584A borders.
  - Headline from the week summary; the bottom lines hide without data.
  - Kept the nights fallback for a week with no skin answers, as you asked.
  - Renders: `design-review/audit-share/week-share-*.png`.
- [x] **B. Doctor report:**
  - One US Letter page on white with 48pt margins, and a second page past 6 weeks.
  - Header "For Dr. Rivera · visit Oct 30", title, and "Age 3 · 4 weeks, logged by Matt".
  - A computed summary sentence, e.g. "Calmer since the plan started Sep 27: flaring days went from 4 a week to 1."
  - Skin by week with itchy wake-ups, good nights, and a "Plan starts" rule.
  - "Following the plan" with done counts since the plan started, "Not started yet", "Notes from home" with swatches, and "Questions for the visit".
  - Body 11pt, nothing under 9pt, rules at 0.75pt or more.
  - Renders: `visit-report-4-weeks-page1.png`, `visit-report-8-weeks-page1/2.png`.
- [x] **Questions for the visit:**
  - A new field on a visit (add a visit, or tap Next visit on Plan).
  - SchemaV9, a lightweight migration.
  - **Push the Supabase migration `20261011120000_visit_questions.sql` before shipping this build.** A visit with questions won't sync until then. Visits without questions sync either way.
- [x] **C. Caregiver card:**
  - 390×844 at 3x.
  - "For Grandma · Oct 11", "Caring for Cal".
  - The plan's skin routine in order, and morning, afternoon and bedtime with amounts.
  - The parent's "If Cal's scratching" and "Please avoid", then Safe snacks and Contacts when filled in.
  - "Questions? Text Matt anytime."
  - Opens from Plan.
  - Render: `caregiver-card.png`.

### Release checks (`audit/release`)
- [x] **App icon:** dark and tinted variants added (made from the "c" mark).
- [~] **Launch screen:** it now matches the paper (#F6EEE2 by day, #201712 in dark mode). The app's night follows the clock, not the phone's dark mode, so a phone in dark mode at noon still flashes dark for a moment. That can't be fixed with a launch color.
- [x] **No clipped text at AX5; works on iPhone SE:**
  - The audit flagged "Afternoon" in To do on SE; it now shrinks slightly instead of clipping.
  - Remaining flags: a few "Dynamic Type partially supported" notes on custom-font headings, and Settings' "Done" button.
- [x] **Contrast:**
  - Token pairs, measured:

    | Pair | Contrast |
    |---|---|
    | Ink on paper | 14.5 |
    | Muted on paper | 5.9 |
    | Accent on paper | 5.7 |
    | Muted on surface | 5.2 |
    | Night ink | 14.2 |
    | Night muted | 7.6 |
    | Night accent | 10.7 |

  - Switch tracks are now 3.4.
  - Apple's audit reports "contrast failed" on nearly every label, including ink on paper. That's the paper grain confusing its sampler, not real contrast.
  - The line color (#DECDB6, 1.35:1) is only used for dividers, never for text or the edge of a control.
- [x] **Reduce Motion:** every animation goes through `Motion.swift`, which swaps in fades.
- [x] **String search:**
  - No "[", "TODO", "Lorem", "Maya" or "APP NAME" in user-visible strings.
  - "Sample" appears only in debug code.
  - "Cali Care" is spelled the same everywhere.
- [x] **App Store screenshots:** 6.9" (1320 × 2868) with the demo plan, in `screenshots/appstore/`.

## New things for you to decide
1. **The caregiver card has no "Not medical advice."** Your spec's footer ("Questions? Text … anytime.") drops it, and CLAUDE.md asks for it on shared reports. I followed the spec.
2. **Night colors now come on at 7 PM, not 8 PM.** One boundary for everything.
3. **The Shortcuts "Get Care Log" action** still makes the older multi-page log with every entry. I left it as the full export. Say if it should become the one-page report.
4. **The caregiver card now opens only from Plan.** Without a plan there's no way in. Add it to the empty Plan screen or Settings?
5. **Notification banners couldn't be captured** in the simulator. Worth a look on the phone.
6. **Home guide step 3 shows the keyboard** (iOS 27 behaviour on the simulator). A real-phone capture would avoid it.
7. **Fixed after the before shots:** in the To do step sheet, the big statement showed through the sheet's header when scrolled. The header is now solid.
