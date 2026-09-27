# DESIGN.md — Cali Care

This file replaces docs/03-design-system.md and the design section of
CLAUDE.md. If anything conflicts, this file wins. Read it before touching
any UI. Every screen, widget, card, and notification must follow it.

## 1. The idea in one line
A beautifully made notebook from a good shop: paper, ink, and indigo.
Think Kinfolk's restraint and Anthropologie's warmth. Not a health app,
not a plant app, not a baby app, not a SaaS dashboard.

What that means in practice:
- Restraint. Lots of paper, very few colors, very few type sizes.
- Structure you can feel: hairline rules, a strict left edge, ledger rows.
- Warm and tactile: a faint paper grain, ink-like fills, real craft.
- Calm at 2 AM: nothing bright, nothing loud, nothing that asks for praise.

## 2. What we refuse (the "AI app" look)
These are the patterns that make apps look generated. Never ship any of
them. If a design needs one, stop and ask.

Type
- No Inter, Geist, Space Grotesk, Instrument Serif, Fraunces, Playfair,
  DM Sans, Poppins.
- No serif-italic accent word inside a sans headline.
- No ALL-CAPS section labels or letter-spaced eyebrow text.
- No big bold centered headlines. Headlines here are regular weight and
  left-aligned.
Color
- No purple or lavender. No gradients. No glows or colored shadows.
- No green as the brand color. No leaf, sprout, droplet, heart, sparkle,
  shield, or stethoscope imagery anywhere, including the logo and icon.
- No red, orange-red, or skin-tone scales for "bad."
Layout
- No card around every piece of content. No nested cards.
- No drop shadows on content. No frosted/glass panels inside content.
- No colored left or top border on cards or callouts.
- No grid of identical tiles with an icon on top.
- No icon inside a colored rounded square.
- No emoji anywhere in the UI.
- No "stat banner" row of big numbers with tiny labels.
- No badges or pills stacked above headings.
Motion and copy
- No bouncy springs, confetti, streak flames, or celebration animations.
- No generic copy: "Something went wrong," "Get started," "Unlock your
  potential," "Powerful insights." Say the specific thing.

Before marking any UI task done, check the screen against this list and
say which items you checked.

## 3. Color
Rule of proportion: about 70% paper, 20% ink, 10% indigo and ochre.

Day palette
| Token | Hex | Use |
|---|---|---|
| paper | #F6F1E8 | Main background everywhere |
| oat | #ECE4D6 | Secondary surface: sheets, selected rows, callouts |
| ink | #1E1B18 | Text, primary buttons, hairlines at full strength |
| graphite | #5C554D | Secondary text, captions, timestamps |
| hairline | #D8CFC0 | 0.5pt rules between rows and sections |
| indigo | #34466A | The one accent: selected states, links, charts |
| ochre | #8A6320 | "Worth watching" text only, used rarely |

Severity and data scale (indigo density, light = calm, deep = hard day)
| Step | Hex |
|---|---|
| 1 calm | #E3E7EE |
| 2 | #C2CBDB |
| 3 | #8C9BB8 |
| 4 | #56698F |
| 5 hard | #2E3E5E |

Night palette (automatic 8 PM – 7 AM)
| Token | Hex | Use |
|---|---|---|
| night | #14161C | Background |
| nightSurface | #1E2129 | Sheets, selected rows |
| nightText | #EAE3D6 | Main text (warm, never pure white) |
| nightSecondary | #A8A093 | Secondary text |
| nightHairline | #2C303A | Rules |
| nightIndigo | #9FB0D0 | Accent |
Night severity scale (brighter = harder): #2A3142, #3C4760, #5A6B8E,
#8497BD, #B7C5E0.

Checked contrast ratios (keep them passing):
ink/paper 15.2, graphite/paper 6.5, graphite/oat 5.8, ochre/paper 4.8,
indigo/paper 8.4, nightText/night 14.2, nightSecondary/night 7.0,
nightIndigo/night 8.3. Add a unit test that computes WCAG contrast for
every text/background token pair and fails under 4.5.

Why indigo: calm, works on every skin tone, can't be confused with skin
or blood, and is not a plant color. Severity is always measured by
symptoms (itch, sleep, spread), never by how skin looks.

## 4. Type
Two families only.

- Newsreader (serif, OFL, bundled): anything a person reads as a
  sentence or a heading. Use its optical sizes: Display cut at 28pt and
  up, Text cut below. Weights 400 and 500 only. Never bold.
- SF Pro (system font): controls, labels, times, numbers in lists. It's
  native, has perfect Dynamic Type, and keeps UI crisp.

If budget allows later, Newsreader can be swapped for a commercial serif
with an app embedding license (GT Alpina or Canela are the right
family). Only DesignSystem.swift should change.

Type scale. Six styles; nothing else is allowed.
| Style | Font | Size/Line | Dynamic Type base | Use |
|---|---|---|---|---|
| display | Newsreader Display 400 | 32/38 | largeTitle | Child's name on Today, report headline. Once per screen at most. |
| title | Newsreader Display 400 | 24/30 | title2 | Screen and section titles |
| lede | Newsreader Text 400 | 20/28 | title3 | The one summary sentence ("A rough night, 3 itchy wake-ups.") |
| body | Newsreader Text 400 | 17/25 | body | Sentences, notes, care plan text |
| control | SF Pro 500 | 17/22 | body | Buttons, row labels, tabs |
| meta | SF Pro 400 | 13/18 | footnote | Times, "by Dad," captions |
Big numbers in reports use display with monospaced (tabular) digits.

Rules
- Left-aligned, always. Centered text only inside a button.
- Sentence case everywhere. No all caps.
- Headings are regular weight; hierarchy comes from size and space, not
  boldness.
- Every style is built with `relativeTo:` so Dynamic Type scales it. Test
  at the largest accessibility size: nothing clips or truncates.

## 5. Layout: the ledger
One layout primitive, repeated until it becomes the look: the ledger row.

Ledger row
- Full width, on paper. Label on the left (control or body), value or
  action on the right (meta or control). 0.5pt hairline below.
- Minimum height 56pt (72pt at night).
- Tap state: the row fills with oat (nightSurface at night), like ink
  soaking into paper. No scale bounce.

Screens are built from: a title, the lede sentence, then ledger sections
separated by 40pt of space. That's it. Surfaces (oat sheets) are used only
for things that sit above the page, like the log confirmation or a sheet.

Spacing: 4pt base. Screen margins 24pt. Between rows 0 (the hairline does
the work). Between sections 40pt. Title to lede 8pt. Lede to first
section 32pt.

Corners: 4pt on buttons and sheets, 2pt on images. Nothing is pill-shaped
except the segmented night/day toggle if one exists.

Buttons
- Primary: ink fill, paper text, 4pt corners, full width, 56pt tall
  (64pt at night). One per screen.
- Secondary: no fill, ink text, 0.5pt ink outline.
- Log buttons (the core action): large ledger rows, not tiles. The label
  is a word a tired parent reads instantly: "Itchy," "Rough night,"
  "Bowel movement," "Routine done."

Texture: a very faint paper grain over paper and oat backgrounds (static
noise image at 3–4% opacity, multiply). Never over text-heavy report
cards that get shared, never in widgets.

System chrome: let iOS draw its own navigation and tab bars (Liquid Glass
on iOS 26+). Don't restyle them and don't imitate glass inside content.
Content stays matte paper.

## 6. Icons, logo, and imagery
- Icons: SF Symbols, regular or light weight, ink or graphite, used only
  where a word alone is unclear. Never in colored containers.
- Logo: a wordmark, "Cali Care," set in Newsreader Display 400. No symbol
  for now. The old leaf is deleted everywhere.
- App icon: paper-colored ground with an ink lowercase "c" from
  Newsreader Display, optically centered. A human illustrator or
  letterer can replace it later.
- Illustration: none until a human illustrator makes them (single-weight
  ink line drawings). Never AI-generated images. Until then, typography
  and whitespace carry every screen.
- Photos of children appear only in the on-device photo timeline.

## 7. Showing, not telling: visual steps
Any instruction that happens outside our app (adding a widget, Lock
Screen widgets, Action Button, Siri, Control Center, notification
permissions, Shortcuts automations) must be shown, not described.

The VisualSteps component
- One step per screen, swipeable. Each step shows an iPhone frame with
  the exact screen the parent will see, with the spot to tap marked by a
  soft indigo ring. Under it, one short sentence in body style:
  "Touch and hold an empty spot on your Home Screen."
- Steps are real screenshots or short looping screen recordings (3–6
  seconds, no sound), never drawings of a phone.
- A "Show me again" link and a "Done" button. Steps can always be skipped.
- Assets live in the asset catalog, named by feature and iOS version
  (e.g. widgetHome_ios27_step1), so they're easy to replace when iOS
  changes.
- Where iOS offers a direct button, use it instead of steps (SiriTipView,
  ShortcutsLink, opening the Settings app).

Capturing the assets
- Simulator: Claude Code captures with
  `xcrun simctl io booted screenshot` and `xcrun simctl io booted
  recordVideo`, on the current iOS.
- Real device only (the human records these with Screen Recording):
  Action Button setup, anything Siri, Control Center on device.
- Blur or remove any personal content in captures.

Current step flows to build (verify each on the current iOS first):
- Home Screen widget: touch and hold an empty spot → tap Edit → Add
  Widget → find Cali Care → pick a size → Add Widget → Done.
- Lock Screen widget: touch and hold the Lock Screen → Customize → Lock
  Screen → tap the widget area → pick Cali Care.
- Action Button: Settings → Action Button → swipe to Shortcut → choose
  "Log itching."
- Control Center: swipe down from the top-right → touch and hold → Add a
  Control → find Cali Care.

## 8. Motion and feedback
- Logging: the row fills with oat over 200ms, a light haptic, and the
  confirmation line slides up from the bottom: "Logged, 2:14 AM · Undo."
  It disappears after 4 seconds.
- Transitions are short (200–300ms) and ease-out. No springs with bounce.
- Reduce Motion on: crossfades only.

## 9. Voice (unchanged, restated)
Plain, warm, short. Like a friend who's been through it. Honest about
uncertainty: "worth watching," "not enough logs yet." Never "cause,"
never shame, never "you missed." Errors say what happened and what to do:
"Couldn't reach the internet. Your log is saved on this phone."

## 10. Report cards
Report cards are the most shared thing we make, so they should look like
a page from a small magazine.
- Paper background (no grain), 24pt margins, a 0.5pt ink rule under the
  wordmark at the top.
- Headline in display ("A calmer week"), the week's dates in meta.
- Ledger rows for the stats, with numbers in display tabular figures.
- Seven night dots and skin-by-day bars on the indigo scale.
- One "worth watching" line in ochre text, no box around it.
- Footer in meta: "Cali Care · Not medical advice."

## 11. Widgets
Widgets use the same palette and type: paper or night background, ink
text, indigo only for the selected or most recent item. The small widget
is one big word ("Itchy") and the last-logged time. No icons unless the
Lock Screen size demands one.

## 12. Definition of done for any UI task
- Uses only tokens and type styles from DesignSystem.swift.
- Checked against section 2, and you've said which items you checked.
- Screenshots of the screen in day and night, and at the largest Dynamic
  Type size, saved to /design-review/<task>/ and listed in your report.
- Contrast test passes.
- VoiceOver reads every control with a clear label.
