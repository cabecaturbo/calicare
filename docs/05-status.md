# Status (October 10, 2026)

Where CaliCare stands. `PROGRESS.md` has the step-by-step checklist, and `docs/06-decisions.md` has the reasons behind each choice.

## Where things are
- **Base branch:** `claude/inspiring-lamport-rmzneg`. Each step gets its own branch off it and merges back through a PR once CI passes. GitHub's default `main` is behind, at PR #47.
- **Built and merged (through PR #92):**
  - Phases 1–5, 6.1 photos, 6.2 product diary, the UX rebuild, V1.0 hierarchy and wording.
  - Tabs: Today, To do, Progress, **Plan** (v4: the star card with week and next visit, Coming up, supplement tiles, Skin care card, item pages with dose steps). SchemaV8 adds `CarePlan.lengthWeeks` and `PlanItem.doseStepsRaw` (Supabase columns pushed).
  - One motion system (`Core/DesignSystem/Motion.swift`, DESIGN.md §8). One star per screen (DESIGN.md §5a).
  - Onboarding matches the app and offers "Bring in your care plan". October 10 onboarding pass: accurate privacy copy, Reminders with Continue and times, "Log in one tap" with the widget in place, the Lock Screen guide's "Remind me later", Today's widget row only when needed, and one set of terms (no "Quick Log").
  - Night colors follow the clock; Settings › Appearance overrides.
- **On the owner's iPhone:** the Release build 1.0 (4).
- **TestFlight:** builds 3, 4 and 5 submitted for beta review (build 2 is approved and live on the public link).
- **Site:** https://calicare.vercel.app, the owner's preferred old layout and wording, with Plan and To do as their own sections showing the current app.
- **Version 1 is slim on purpose:**
  - Food extras are hidden (`Features.foodExtras`).
  - Out of version 1: 6.3–6.5, 7.2 and 7.4.
  - The Watch comes after launch.
  - **No paywall: version 1 is free during beta** (October 4, 2026).

## Left for the owner
1. **Phone checks (owner):**
   - a real care plan import
   - the doctor PDF in Files and Mail
   - photos and products
   - meal ideas (needs sign-in)
   - the Shortcuts automation
2. **Two-phone test (owner):** join with an invite code (2.4) and "by Dad" names (2.5).
3. **Apple sign-in token removal on account deletion:** code merged (PR #57). Manual: create a Sign in with Apple key on developer.apple.com, then set the APPLE_* Supabase secrets and deploy `delete-account`.
4. **7.6 TestFlight:**
   - App record created October 5, 2026; builds 2 (approved), 3 and 4 (in review). Owner is in the Team group.
   - Public link: https://testflight.apple.com/join/ABXetDtE
   - Invite 5–10 eczema parents.
   - Ideally, a pediatric dermatologist reviews the reports and wording.

## Already done for the App Store
- **Landing page and privacy policy:** https://calicare.vercel.app and /privacy, linked from Settings.
- **Data export:** CSV and journal PDF, in Settings › Your data.
- **Contact support:** msmccartin@gmail.com for now.
- **App icon.**
- **Account deletion:** Edge Function plus SQL, verified on the phone.

## Accounts and tools
- **CLIs:** `asc` (profile CursorKittens), `gh` (cabecaturbo), `supabase`, `vercel`.
- **Supabase project:** `calicare` (ref `sbzuoqxgtbpobnrqqmhw`).
- **Edge Functions:** `delete-account`, `parse-care-plan`, `meal-ideas`.
- **Test device:** iPhone 15 Pro.
- **App Store Connect:** app "Cali Care", ID 6819521789, SKU calicare. TestFlight groups: Team (internal), Beta parents (public link).
