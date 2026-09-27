# DESIGN.md — Cali Care

This file replaces docs/03-design-system.md and the design section of
CLAUDE.md. If anything conflicts, this file wins. Read it before touching
any UI. Every screen, widget, card, and notification must follow it.

## 0. Foundation: Apple's Human Interface Guidelines
Our base design system is Apple's Human Interface Guidelines (HIG). This
file is our brand layer on top of it. Where this file is silent, follow
the HIG. Where they conflict on legibility, accessibility, or platform
behavior, the HIG wins. Read the relevant HIG page before building a
component: Typography, Color, Layout, Accessibility, Tab bars, Lists and
tables, Sheets, Charts, Onboarding, Widgets, Notifications.
Use Apple's system components and behaviors; restyle them with our
tokens, don't replace them.

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
Tokens live in one place (the canvas's `tokens.css`; in the app,
`DesignSystem.swift`). Nothing else hard-codes a color.

Day
| Token | Hex | Use |
|---|---|---|
| bg | #F6F1E8 | Page background |
| surface | #ECE4D6 | Summary cards, segmented control track, selected choice |
| ink | #1E1B18 | Text |
| muted | #5C554D | Secondary text, captions, swatch borders |
| line | #D8CFC0 | 0.5pt dividers inside lists |
| accent | #34466A | The one accent: primary buttons, active tab, selection, links |
| onAccent | #F6F1E8 | Text on accent |

Night (automatic 8 PM – 7 AM; every tab, so nothing is bright at 2 AM)
| Token | Hex |
|---|---|
| bg | #14161C |
| surface | #1E2129 |
| ink | #EAE3D6 |
| muted | #A8A093 |
| line | #2C303A |
| accent | #9FB0D0 |
| onAccent | #14161C |

There is no ochre and no other accent. "Worth watching" is a muted
caption inside the summary card.

One scale for skin answers and for nights
| Answer | Day | Night |
|---|---|---|
| calm | #E3E7EE | #2A3142 |
| a little itchy | #C2CBDB | #3C4760 |
| flaring | #56698F | #8497BD |
| very rough | #2E3E5E | #B7C5E0 |
Nights use the same four: good = calm, okay = a little itchy, rough =
very rough.

Drawing the scale
- The rule in both themes: rougher always stands out more. By day,
  deeper is rougher; at night, brighter is rougher.
- Every swatch, bar, and dot has a 1px muted border, so calm never
  vanishes into the background.
- Color is never the only signal: bar height also encodes the answer.
- A day with no skin answer is an empty dashed outline ("not answered").
- Never infer skin from itches or flares. Skin by day comes only from
  the skinToday answer.

Contrast (checked; keep passing): every text token on bg and surface is
at least 4.5:1 in both themes (lowest: day muted on surface 5.8, night
muted on surface 6.2). Keep the unit test that computes WCAG contrast
for every text/background pair.

Why indigo: calm, works on every skin tone, can't be confused with skin
or blood, and is not a plant color. Severity is always measured by
symptoms (itch, sleep, spread), never by how skin looks.

## 4. Type
Two families. Five sizes, plus tab labels. Nothing else.

| Style | Font | Weight | Size/Line | Dynamic Type base | Use |
|---|---|---|---|---|---|
| display | Newsreader | 500 | 34/40 | largeTitle | The screen title ("Today", "Plan", "Progress"); the Welcome headline |
| title | Newsreader | 500 | 24/30 | title2 | Summary card titles, the skin question, onboarding headings, big hero words |
| body | SF Pro | 400 | 17/24 | body | All body copy and row labels, including onboarding |
| label | SF Pro | 600 | 15/20 | subheadline | Section labels, the child switcher, primary button text |
| caption | SF Pro | 400 | 13/18 | footnote | Times, eyebrows, footnotes, legends |
Tab labels: SF Pro 12/16, the only exception (minimum 12).

- The serif is for headlines and hero words only. Never for body copy.
- Weights: 400, 500 (serif), 600 (labels). Never Light or Bold.
- Contrast: ink for primary text, muted for secondary. Nothing lighter.
  Disabled controls use the standard iOS disabled appearance.
- Left-aligned, sentence case, no all caps. Every style scales with
  Dynamic Type, and the hierarchy must still read at the largest size.
- Newsreader ships with weights 400 and 500. Fallback: New York.

## 5. Layout
Every tab is built the same way, top to bottom:
1. **AppHeader:** the child switcher ("Cal ▾", label) on the left, the
   settings gear on the right; below it the screen title in display,
   matching the tab name; an optional caption.
2. **The one thing now:** a summary card (or, on Today until it's
   answered, the skin check-in).
3. **Everything else:** sections with a label, rows separated by 0.5pt
   dividers.
4. **Bottom bar:** the tab bar, and the log control to its right.

Spacing: 4 / 8 / 12 / 16 / 24 / 32. Page gutters 24. Between sections
32. Content scrolls with bottom padding equal to the bottom bar plus the
safe area, so nothing sits under it.

Corners: 12pt on buttons, cards, inputs, and choices. Pill shape only for
the tab bar, the log control, and the segmented control. Chart marks 3pt.

Separators: filled surface cards for summaries; 0.5pt line dividers
inside lists. No heavy rules above sections.

Summary card: surface fill, 12pt corners, caption eyebrow, serif title,
muted caption, and an optional ink drawing on the right. Used for "Last
night", "Up next", and the Progress headline. One per screen.

Log control: one control, the same place on every tab: a pill beside the
tab bar with "Itchy" (one tap) and "More" (Flare, Bowel movement, Note).
It stays quieter than the active tab and than an unanswered check-in.
At night it is taller. On Today at night only, a large full-width
"Itchy" button (title size, about 96pt, accent fill) sits right under the
summary card, and the pill shows just "More".

Skin check-in (Today, until answered): the question in title size and
four card buttons (swatch + label, at least 44pt, selected = accent
border on surface). Once answered it collapses to one line: "Skin
today: A little itchy · Change".

Buttons
- Primary: accent fill, onAccent label, 12pt corners, full width, 56pt.
  One per screen.
- Secondary: 1pt ink outline, 12pt corners (e.g. "Share with provider").
- Text buttons: accent text, at least 44pt tall.

Segmented control: the system segmented control, tinted with tokens
(Progress: Week / Month / Since visit), at least 44pt tall.

Tap targets: at least 44 × 44pt everywhere.

Texture: a very faint paper grain over bg and surface (static noise at
3–4%, multiply). Never on shared report cards or widgets.

System chrome: let iOS draw its own navigation and tab bars (Liquid Glass
on iOS 26+), styled with the tokens. Content stays matte.

## 6. Icons, logo, and imagery
- Icons: SF Symbols, regular weight only, ink or muted, used only
  where a word alone is unclear. Never in colored containers.
- Logo: a wordmark, "Cali Care," set in Newsreader Display 400. No symbol
  for now. The old leaf is deleted everywhere.
- App icon: paper-colored ground with an ink lowercase "c" from
  Newsreader Display, optically centered. A human illustrator or
  letterer can replace it later.
- Illustration: hand-drawn single-weight ink line drawings (1.6pt,
  round caps, ink color): a sun (day, Welcome), a moon (night, evening),
  a flower (Progress). No leaves or sprouts. They sit on the right of a
  summary card or large in onboarding. A human illustrator can redraw
  them later; never AI-generated raster images.
- Photos of children appear only in the on-device photo timeline.

## 7. Showing, not telling: visual steps
Any instruction that happens outside our app (adding a widget, Lock
Screen widgets, Action Button, Siri, Control Center, notification
permissions, Shortcuts automations) must be shown, not described.

**Matched to iOS 27.0** (the current simulator runtime, iPhone 17), checked
September 27, 2026 against simulator captures in
`design-review/redesign/steps/` (widgetHome_, widgetLock_ and
controlCenter_ios27_step*). Re-check whenever iOS changes and update the
wording and drawings together.

The setup guide ("Show me how")
- One step per screen: "Step N of M", a back button, the iPhone at that
  exact moment with a highlight ring and a finger-tap marker on what to
  press, one sentence of instruction (title), then Back and Next. The
  last screen says "You're set." and invites one real tap.
- The iPhone is a drawn frame at true size (393 × 852 pt screen, Dynamic
  Island, 9:41 status bar, calm neutral wallpaper, correct 4-column grid
  and dock, neutral placeholder icons with generic names, never real
  third-party icons or logos). Apple's device bezels aren't available
  here, so the frame is drawn; its values are `--mock-*` tokens.
- These drawings are replaced by real simulator screenshots once the
  restyled widgets ship (saved to `design/screenshots/`).
- Where iOS offers a direct button, use it instead of steps (SiriTipView,
  ShortcutsLink, opening the Settings app).
- Assets are named by feature and iOS version (widgetHome_ios27_step1).

The three paths, in iOS 27 wording
- Home Screen widget (4 steps):
  1. Touch and hold an empty area of your Home Screen until the apps
     jiggle.
  2. Tap Edit in the top-left corner, then Add Widget. (Edit opens a
     menu: Add Widget, Customize, Edit Wallpaper, Edit Pages.)
  3. Search for CaliCare, tap it, and swipe to pick a size. (The gallery
     shows the bundle name, "CaliCare".)
  4. Tap Add Widget, then tap the checkmark in the top-right corner.
     (iOS 27's Done is a checkmark.)
- Lock Screen widget (3 steps):
  1. Touch and hold your Lock Screen, then tap Customize. (It opens the
     Lock Screen editor directly.)
  2. Tap the widget area under the clock, then CaliCare.
  3. Tap Itchy to add it, then tap Done.
- Control Center control (3 steps):
  1. Swipe down from the top-right corner to open Control Center.
  2. Touch and hold an empty area, then tap Add a Control. (Or tap +.)
  3. Search for CaliCare, then tap Log Itchy. Tap an empty area to finish.
- Action Button (iPhones that have one): Settings › Action Button ›
  Controls › Log Itchy.

Capturing the assets
- Simulator: the `DesignReview` scheme's UI tests drive Springboard and
  save screenshots (StepAssetTests, ControlCenterStepTests,
  WidgetReviewTests).
- Real device only (the human records these): Action Button, Siri.
- Blur or remove any personal content in captures.

## 8. Motion and feedback
- Illustrations draw themselves in once (about 1 second) and then stop.
  Only onboarding may keep a gentle hand-drawn wobble.
- Logging: a light haptic and the confirmation line slides up: "Logged,
  2:14 AM · Undo." It disappears after 4 seconds.
- Transitions are short (200–300ms) and ease-out. No springs with bounce.
- Reduce Motion on: no animation at all; drawings appear complete.

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
- Seven night dots and skin-by-day bars on the one scale, each with its
  1px muted border.
- One "worth watching" line in muted text, no box around it.
- Footer in meta: "Cali Care · Not medical advice."

## 11. Widgets
Sizes at true point size for a 393-pt-wide iPhone. Inside the system's
shape: our tokens, the serif only for "Itchy", sans everywhere else, 12pt
inner corners.

- Small (158 × 158): one big Itchy button (logs without opening the app,
  an interactive widget) and "Last: 1:52 AM". After a tap: "Logged ·
  2:14 AM" with an Undo button (44pt) for 5 seconds.
- Medium (338 × 158): "Tonight: 2 wake-ups", Itchy (primary), Flare and
  Note (secondary), "Last 1:52 AM".
- Lock Screen circular (72 × 72): one-tap "Itchy" (the one widget-only
  type exception: serif 17).
- Lock Screen rectangular (160 × 72): "Tonight: 2 · Last 1:52 AM".
- Control (Control Center and the Lock Screen): "Log Itchy", small and
  wide. It can be assigned to the Action Button.

Looks (iOS 27, as since iOS 26): Home Screen widgets render full color,
tinted, and clear, each in light and dark. Full color uses our palette
(night palette in dark). Tinted and clear have no fills of their own:
content becomes one tint or white on glass, so hierarchy comes from size
and weight only, and every piece of text stays at least 4.5:1 on the
glass over the wallpaper. Lock Screen widgets and controls are always
monochrome on dark glass.

## 12. Definition of done for any UI task
- Uses only tokens and type styles from DesignSystem.swift.
- Checked against section 2, and you've said which items you checked.
- Screenshots of the screen in day and night, and at the largest Dynamic
  Type size, saved to /design-review/<task>/ and listed in your report.
- Contrast test passes.
- VoiceOver reads every control with a clear label.
