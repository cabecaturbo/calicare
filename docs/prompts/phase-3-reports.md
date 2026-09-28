# Phase 3: Report cards

Goal: one tap to share how the week went, by text, email, or PDF.
Card specs are in docs/03-design-system.md ("Report cards").

---

## 3.1 Weekly stats engine
Pure logic in Core, no UI.
1. WeeklyReport(child, weekEnding) computes: good nights out of 7,
   itchy wake-ups vs last week, routine completion, skin level by day
   (use the same daily skin level the Today strip uses), bowel movements,
   mood summary.
2. Headline sentence from simple rules: "A calmer week," "A harder week,"
   "About the same as last week," "Not enough logs yet for a summary."
3. One "worth watching" line, only when there's a clear change
   (e.g. itchy wake-ups up 3+ vs last week). Wording notices, never
   explains: "Itchy wake-ups went up this week." Never "caused by."
4. Missing days are simply excluded, never shown as failures.
5. "New safe foods" is a placeholder field, empty until Phase 5.
6. Thorough tests: normal week, empty week, partial week, two children,
   time zone and night boundary.
Done when: tests pass.

---

## 3.2 Weekly report card image and share sheet
1. WeeklyCardView (600×750) matching the design system spec: headline,
   trend pill, 7 night dots, itchy wake-ups vs last week, routine
   completion, skin-by-day sage bars, one worth-watching callout (sand
   box), footer "Not medical advice."
2. Always the light palette, even at night.
3. Render with ImageRenderer at 3x. Share sheet with the image.
4. Reports screen: pick child and week, preview, Share.
5. Snapshot or render test with sample data, including the empty state.
Done when: the card shares correctly to Messages and Mail on device.

---

## 3.3 🛑 iMessage extension
Manual: new Messages extension target (via project.yml) with the App Group
and keychain group; test on device.
1. Messages extension shows this week's card for each child.
2. Tap to insert a compact bubble: 3 stats plus "Tap to see full week."
   The full card image opens when tapped.
3. Reads from the shared SwiftData store; read-only.
4. Works with no network.
Done when: sending a card in Messages works on device.

---

## 3.4 Doctor PDF
1. Doctor report for a chosen date range (default: since the last visit
   date if known, else 4 weeks).
2. Pages: summary stats, sleep and itch trend chart (Swift Charts
   rendered into the PDF), skin by day, bowel movements, notes, and a full
   log table.
3. Neutral, clinical-friendly wording. No conclusions. Footer on every
   page: child name, date range, "Not medical advice. Logged by parent."
4. Share sheet and Mail compose.
5. Tests for date range selection and table content.
Done when: a clean multi-page PDF opens in Files and Mail.

---

## 3.5 Caregiver card
Lives in Progress › Share (next to "Share with provider"), in the phone's
style; the card itself follows DESIGN.md §10 (paper, Newsreader headline,
ledger rows, "Not medical advice" footer).
1. Parent-entered fields: bedtime routine steps (prefilled from Plan's
   routine steps, editable), safe snacks, please avoid, "if [child] is
   scratching," contacts.
2. Card image (600 × 750 at 3x) and a one-page PDF.
3. Nothing is pre-filled with advice. Empty sections are hidden.
   (Phase 4 can fill fields from the care plan, with parent approval.)
4. Share sheet.
Done when: the card renders and shares; empty fields don't appear; builds
clean; tests pass.

---

## 3.6 Scheduled sends via Shortcuts
1. App Intent "Get weekly report card" (child, week) returns the image
   file so Shortcuts can send it.
2. App Intent "Get doctor report" (child, date range) returns the PDF.
3. A help screen in Settings › Quick logging, in the setup-guide style
   (real screenshots, one step per screen): create a Personal Automation
   (for example Sunday 7 PM → send the card to a partner in Messages).
Done when: the automation runs on the owner's phone and sends the card.
