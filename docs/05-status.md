# Status (October 4, 2026)

Where CaliCare stands. `PROGRESS.md` has the step-by-step checklist, and `docs/06-decisions.md` has the reasons behind each choice.

## Where things are
- **Base branch:** `claude/inspiring-lamport-rmzneg`. Each step gets its own branch off it and merges back through a PR once CI passes. GitHub's default `main` is behind, at PR #47.
- **Built:**
  - Phases 1–5.
  - 6.1 photos and 6.2 product diary.
  - The UX rebuild.
  - V1.0 hierarchy and wording.
  - V1.0b To do + Info (SchemaV7).
- **On the owner's iPhone:** the app as of PR #52. The "plain and obvious" redesign (PR #53) was reverted in PR #54 at the owner's request.
- **Version 1 is slim on purpose:**
  - Food extras are hidden (`Features.foodExtras`).
  - Out of version 1: 6.3–6.5, 7.2 and 7.4.
  - The Watch comes after launch.
  - **No paywall: version 1 is free during beta** (October 4, 2026).

## To finish before TestFlight
1. **Phone checks (owner):**
   - a real care plan import
   - the doctor PDF in Files and Mail
   - photos and products
   - meal ideas (needs sign-in)
   - the Shortcuts automation
2. **Two-phone test (owner):** join with an invite code (2.4) and "by Dad" names (2.5).
3. **Apple sign-in token removal on account deletion:** code merged (PR #57). Manual: create a Sign in with Apple key on developer.apple.com, then set the APPLE_* Supabase secrets and deploy `delete-account`.
4. **7.6 TestFlight:**
   - Create the App Store record and upload a build. Ask the owner before each.
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
- **App Store Connect:** no app record yet.
