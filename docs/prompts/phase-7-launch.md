# Phase 7: Launch

Goal: ready for families beyond ours.

---

## 7.1 🛑 Apple Watch app
Manual: add the Watch target via project.yml; test on the owner's watch.
1. One-tap Itchy (big, dark, works in the dark), last-night rating, a
   complication.
2. Logs sync through the phone; works when the phone is out of reach
   (queued).
Done when: logging from the watch works on the owner's watch at night.

---

## 7.2 Keyboard extension
A bonus only (iOS's "Full Access" warning scares people).
1. A keyboard row with Itchy, Flare, and Note, working without Full
   Access if possible.
Done when: it logs from Messages on the phone.

---

## 7.3 🛑 Premium paywall
Product decisions needed from the owner: prices and what's in premium
(the brief suggests about $5.99/month or $44.99/year).
1. StoreKit 2 subscriptions. Free forever: logging, multiple children,
   caregiver sync, basic reports. Premium: insights, care plan import,
   supplement scheduler, meal ideas, full doctor and insurance reports,
   the full photo timeline.
2. No dark patterns: clear prices, easy restore, easy cancel link, no
   countdowns.
Done when: purchase, restore, and cancel work in the sandbox on the
phone.

---

## 7.4 Monthly recap
1. A calm monthly "how far you've come" recap (the parent's own history
   only). No streaks, no guilt.
Done when: the recap renders from real data and shares.

---

## 7.5 🛑 Vercel landing page and privacy policy
Manual: the owner's Vercel account and domain.
1. A landing page in the app's style, an "EczemaWise alternative" page,
   and a privacy policy (photos stay on the phone, what syncs, AI use).
2. Link the privacy policy from Settings › About.
Done when: the pages are live on the owner's domain.

---

## 7.6 🛑 Launch readiness and TestFlight
Before the App Store (from autopilot.md):
1. Data export and About (done in UX.5): check.
2. Apple sign-in token removal when an account is deleted (needs a key
   from the owner's Apple Developer account).
3. A two-phone test of family sharing.
4. A pediatric dermatologist reviews the reports and wording.
5. TestFlight with eczema parent groups.
6. App Store listing and submission (ask before creating the app record,
   uploading, or submitting).
Done when: TestFlight is out to the parent groups.
