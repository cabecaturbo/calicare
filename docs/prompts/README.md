# How to run the prompts

Every remaining build prompt lives in this folder, one file per phase.
PROGRESS.md in the repo root tracks which prompts are done.

## Rules for Claude Code
1. Do exactly ONE prompt per session: the first unchecked one in PROGRESS.md.
2. Before planning, inspect the code that exists. Earlier prompts may have
   used different names than these docs. Adapt to the real code; don't
   rename working code to match the docs.
3. If a prompt conflicts with CLAUDE.md, the product principles, or the
   existing code, STOP and ask. Don't guess.
4. Plan first. Wait for approval before editing files.
5. A prompt marked 🛑 MANUAL has steps only the human can do (Apple
   Developer portal, Supabase dashboard, App Store Connect, device
   testing). List them clearly and STOP until the human confirms they're
   done.
6. Done means: builds cleanly, tests pass, "Done when" is met.
7. When done: commit with a clear message, check the box in PROGRESS.md,
   add a one-line note under it (what was built, anything left over),
   and add any new decisions to docs/06-decisions.md.
8. Then STOP. Never start the next prompt on your own.

## Standard kickoff (paste this after every /clear)
```
Read CLAUDE.md, PROGRESS.md, and docs/prompts/README.md. Find the first
unchecked prompt and read it in its phase file. Inspect the existing code
it touches. Then give me your plan and wait for my approval.
```

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
