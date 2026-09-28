# How to run the prompts

Every remaining build prompt lives in this folder, one file per phase.
PROGRESS.md in the repo root tracks which prompts are done.

## Rules for Claude Code (autopilot)
autopilot.md in the repo root is the operating manual. In short:
1. Do the next unchecked step in PROGRESS.md, reading its phase file.
2. Inspect the code first; adapt to what exists.
3. Plan, build, test, save it to main (PR with CI, then merge), update
   PROGRESS.md and docs/06-decisions.md, then go to the next step.
4. Make technical decisions yourself; ask the owner only about product,
   money, or taste.
5. Stop only when a phase is finished (put it on the owner's phone and
   say in plain words what to try), when something needs the owner
   (🛑 steps, accounts, keys, a second phone), or when something is broken
   after a real attempt. No jargon when talking to the owner.
6. The owner's phone is the design reference; DESIGN.md and UX.md
   describe it.

## After a /clear or a new session
Read autopilot.md and PROGRESS.md, say in one sentence where we are, and
continue.

## Standing rules that apply to every prompt
- Product principles in CLAUDE.md always win.
- The app never recommends treatments, doses, foods, or products. It only
  organizes what the family's provider wrote, or what the parent enters.
- No red, no streaks, no guilt, no "you missed."
- Kids' photos never leave the device.
- Everything works offline first; sync is a bonus.
- No secrets in the app or repo. AI calls only through Edge Functions.
- VoiceOver labels, 44pt+ targets, Dynamic Type, night palette.
- Every shared report ends with "Not medical advice."
