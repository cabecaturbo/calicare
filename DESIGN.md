# DESIGN.md — Cali Care

This file replaces docs/03-design-system.md and the design section of
CLAUDE.md. The app on the owner's phone is the reference for how things
look: if it differs from this file, update this file. Read it before touching
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
A beautifully made notebook from a good shop: blush paper, ink, dusty rose, and sage.
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
**This file describes the app as it is on the owner's phone (main, September
27, 2026).** The phone is the reference; if this file and the phone disagree,
fix this file. Tokens live in `Core/DesignSystem/DesignSystem.swift`.

Day (and night: since October 5, 2026 there's no dark mode; after 8 PM the
app keeps its night layout, with the bigger Log button and rows, in these colors)
| Token | Hex | Use |
|---|---|---|
| paper | #F9F0EC | Page background (blush), the bottom bar, the Itchy pill |
| oat | #F2E2DC | Summary cards, the active tab, selected choice |
| ink | #2B1D1F | Text, primary buttons, outlines |
| graphite | #6E5A5C | Secondary text, captions, swatch borders |
| hairline | #E6D0CA | 0.5pt dividers, card and pill borders |
| accent (dusty rose) | #9E4357 | The one accent: links, "Change", checks, the Log buttons |
| ochre | #8A6320 | "Worth watching" text only, on paper |

One scale for skin answers and for nights (warm sage)
| Answer | Hex |
|---|---|
| calm | #EAEDE1 |
| a little itchy | #CCD6BF |
| flaring | #8FA382 |
| very rough | #56704C |
Nights use the same marks: good = calm, okay = a little itchy, rough = very
rough. (A fifth, middle step, #ADBDA0, is still in the palette but unused.)

Drawing the scale
- Rougher always stands out more: deeper sage.
- Every swatch, bar, and dot has a 1pt graphite border.
- Skin bars are taller for rougher days.
- A day with no skin answer is a short graphite dash (12 × 2pt), no bar.
- Never infer skin from itches or flares. Skin comes only from the daily
  answer.

Contrast: every text color passes 4.5:1 on paper and oat in both themes;
the unit test checks each pair.

Why blush and rose (owner, October 5, 2026): a warm, soft palette in place
of blue, picked from four warm options. Rose is only the accent (buttons,
links, checks), never a severity, so "rough" is never shown in a red-like
color. The skin scale is warm sage, deeper for rougher, and can't be
confused with skin or blood. No dark mode.

## 4. Type
Two families.

| Style (code name) | Font | Size/Line | Use on the phone |
|---|---|---|---|
| display | Newsreader Display, weight 500 | 34/40 | The tab title ("Today", "Plan", "Progress") |
| title (also lede) | Newsreader Display, weight 500 | 24/30 | Summary card titles ("A good night"), the skin question, the night Itchy button |
| section | Newsreader Display, weight 500 | 20/26 (title3) | Section headers ("Evening", "Supplements", "This week", Settings groups) |
| label | SF Pro semibold | 15/20 | The child switcher, step numbers, outlined button labels ("Share with provider") |
| body (also control) | SF Pro regular | 17/24 | Row labels, answers, body text, buttons |
| meta | SF Pro regular | 13/18 | The date, eyebrows ("Last night"), captions, times |
Tab labels are SF Pro 12 (medium, semibold when active). The Itchy pill
label is SF Pro 13 semibold.

- Newsreader Display 500 is cut from the Google Fonts variable font and
  bundled (Newsreader Display 400 and Text 400 are bundled too).
- Four levels on every screen: screen title (display), section header
  (section, serif), row (body), meta (footnote, graphite). The serif is for
  those titles and headers, card titles, and the skin question; everything
  else is SF Pro.
- One focal point per screen, at the top: Today and Plan, the summary card;
  Food, the food counts ("6 safe foods"). Nothing else matches it in size.
- Shared cards and PDFs (weekly card, caregiver card, journal) keep SF Pro
  semibold (label) for their headings, since they're fixed-size pages.
- Sentence case, left-aligned. Every style scales with Dynamic Type.
- At accessibility sizes (AX1 and up): the skin answers go to one column,
  Good / Okay / Rough stack, summary cards drop their drawing so the title
  has the full width, and the bottom bar keeps a fixed size (it already
  carries labels and is the one place that can't grow).

## 5. Layout
Every tab, top to bottom:
1. **Header:** the child switcher ("Cal ▾") on the left and a gear button
   (44pt circle with a hairline border) on the right; then the tab name in
   display type; on Today by day, the date under it.
2. **The one thing now:** on Today by day, the skin check-in until it's
   answered; then a summary card.
3. **Everything else:** a section label, then rows with 0.5pt dividers.
4. **The bottom bar:** Apple's glass tab bar with the round Log button.

Spacing: 4 / 8 / 16 / 24 / 40. Page margins 24. Sections 40 apart; a
header sits 8 above its rows. Space inside a group is always smaller than
space between groups. Content scrolls with 120pt of room at the bottom for
the bar. A paper strip sits behind the status bar so nothing scrolls under
the clock; sheet and pushed-screen headers are solid (oat or paper).
Shared cards keep 12 and 32 (CardSpacing) so their fixed pages don't reflow.

Corners: 12pt on summary cards, choice cards, buttons, and the "Logged"
line. Pills (fully round) for the tab bar and the log control. 3pt on
swatches and chart marks.

**Summary card:** oat fill, 12pt corners, 16pt padding, at least 128pt tall.
A small eyebrow (meta, graphite), a serif title, an optional caption (meta,
graphite), and a hand-drawn drawing on the right (84 × 80): the sun on
Today by day, the moon at night and for the evening routine, the flower on
Progress.

**Skin check-in (Today, by day, until answered):** "How was Cal's skin
today?" (title), "One tap. You can change it later." (meta), then four
choice cards in a 2 × 2 grid: paper fill, 1pt hairline border, 12pt
corners, 64pt tall, a 24pt swatch and the answer. The selected card has an
oat fill, a 2pt indigo border, and a small indigo check badge on its
corner. Once answered it becomes one line: a swatch, "Skin today: a little
itchy", and "Change" in indigo.

**Rows ("Today so far", Plan's routines):** at least 52pt, 0.5pt hairline
below, label in body, time or status in meta on the right.

**Routine steps:** a check circle (24pt, its own 44pt target), the label
(verb first, at most 6 words), and one meta line (the plan's detail, or how
often). Tapping the words shows the plan's original line. Consecutive Apply
steps sit under "Skin" (hand symbol, graphite) with a hairline pill for how
often ("3-4x per day"), numbered 1, 2, 3. Step categories each have a verb
and a regular-weight SF Symbol: Wash `drop`, Apply `hand.point.up.left`,
Give `pills`, Feed `fork.knife`, Dress `tshirt`.

**Supplements:** the name (no "ADD"; a small indigo outlined "New" pill
instead), one meta line (dose · frequency), "How to give" in indigo with a
chevron for the plan's directions, and the same outlined pill on the right
every time: "Start", then "0 of 2 today". "Your provider mentioned" lines
sit underneath in meta graphite, with no actions.

**Night Today:** a large Log button right under the summary card: indigo
fill, paper text, 96pt tall, 12pt corners, the palm and "Log" in title
type, and "Last at 1:52 AM" under it.

**The word "Itchy" never appears on a button.** Buttons that log itching
show the palm (hand.raised.fill) and "Log"; VoiceOver says "Log itching".
Logs, reports, and sentences still say "itchy wake-up".

**Bottom bar (iOS 26.1 and later):** Apple's glass tab bar: Today, Plan,
Progress (system symbols and labels, the active tab tinted indigo; it
follows day and night through the color scheme), and, set apart on the
right, the round **Log** button: the palm with "Log" under it (the `.search`
role on iOS 26, `.prominent` on iOS 27). One tap logs itching and stays on
the current tab. The bar shrinks as you scroll down. The "Logged, 2:14 AM
· Undo" line sits just above it. Flare, Bowel movement, Mood, and Note are
the "•••" button (an oat circle) beside "Today so far" on Today.

Older phones (before iOS 26.1) keep our own bar: a tab pill (62pt, 18pt
symbols over 12pt labels, active tab oat with indigo text by day, indigo
with paper text at night) and a log pill with the palm and "Log" plus
"•••", over a 48pt fade.

**Buttons:**
- Primary: ink fill, paper text, 12pt corners, full width, 56pt (64pt at
  night).
- Secondary: 0.5pt ink outline, ink text, 12pt corners ("Share with
  provider": 1pt ink outline, 52pt).
- Text links: indigo ("Change", "Share this week's card").

**Settings:** a grouped list on paper with SF section headers.

Texture: a very faint paper grain over paper and oat. Never in widgets or
shared report cards.

## 6. Icons, logo, and imagery
- Icons: SF Symbols, regular weight only, ink or muted, used only
  where a word alone is unclear. Never in colored containers.
- Logo: a wordmark, "Cali Care," set in Newsreader Display 400. No symbol
  for now. The old leaf is deleted everywhere.
- App icon: paper-colored ground with an ink lowercase "c" from
  Newsreader Display, optically centered. A human illustrator or
  letterer can replace it later.
- Illustration: hand-drawn single-weight ink line drawings (1.6pt,
  round caps, ink color), one set per screen: Today's sun (day, also
  Welcome) and moon (night); Plan's sprout (morning routine) and lamp
  (evening routine); Progress's flower (Week) and small tree (Month). The
  owner picked these on September 28. They sit on the right of a
  summary card or large in onboarding. A human illustrator can redraw
  them later; never AI-generated raster images.
- Photos of children appear only in the on-device photo timeline.

## 7. Showing, not telling: visual steps
Any instruction that happens outside our app (adding a widget, Lock
Screen widgets, Action Button, Siri, Control Center, notification
permissions, Shortcuts automations) must be shown, not described.

**The app's display name is "Cali Care"** (CFBundleDisplayName), so that's what
the Home Screen label, the widget gallery, and Control Center search show; the
guides say "Search for Cali Care". The control and the widget are named "Log".

**Matched to iOS 27.0** (the current simulator runtime, iPhone 17), checked
September 27, 2026 against simulator captures in
`design-review/redesign/steps/` (widgetHome_, widgetLock_ and
controlCenter_ios27_step*). Re-check whenever iOS changes and update the
wording and drawings together.

**In the app:** onboarding's "Show me how" and Settings › Quick logging open
the setup guide below (`SetupGuide`, `GuideScreenshot`). Home Screen widget,
Lock Screen widget, and Control Center; the Action Button is hidden until
it's recorded on a real iPhone.

The setup guide ("Show me how")
- One step per screen: the guide's name (section style), a close button,
  and a thin progress line; the **real iOS 27 simulator screenshot** of
  that exact moment, rounded like the phone, filling the space between;
  an indigo ring (40pt, 3pt line) with a dot on the tap spot; a round
  zoom callout (112pt, about 2.4×, paper edge and a soft shadow) beside
  the phone at the tap's height, on the side away from the tap; one
  sentence in sans body, centered, at most three lines; Back (text) and
  Next (primary). Swipe works too.
- CTA labels: "Next" on every step, "Done" on the final screen.
- The final screen says only "You're set." over the real screenshot of
  the result. No instructions there.
- One date everywhere: Sunday, September 27 (the captures' date).
- Captures come from `scripts/capture-guides.sh` on a separate simulator
  ("CaliCare Captures", erased first) and live in
  `design/screenshots/guide` and `design/screenshots/looks`.
- The drawn iPhone (393 × 852, `--mock-*` tokens) is kept only as a
  fallback for moments that can't be captured. Real captures are iPhone 17
  size (402 × 874).
- Where iOS offers a direct button, use it instead of steps (SiriTipView,
  ShortcutsLink, opening the Settings app).
- Assets are named by feature and iOS version (widgetHome_ios27_step1).

The three paths, in iOS 27 wording
- Home Screen widget (4 steps):
  1. Touch and hold an empty area of your Home Screen until the apps
     jiggle.
  2. Tap Edit in the top-left corner, then Add Widget. (Edit opens a
     menu: Add Widget, Customize, Edit Wallpaper, Edit Pages.)
  3. Search for Cali Care, tap it, and swipe to pick a size.
  4. Tap Add Widget, then tap the checkmark in the top-right corner.
     (iOS 27's Done is a checkmark.)
- Lock Screen widget (3 steps):
  1. Touch and hold your Lock Screen, then tap Customize. (It opens the
     Lock Screen editor directly.)
  2. Tap the widget area under the clock, then Cali Care.
  3. Tap Itchy to add it, then tap Done.
- Control Center control (3 steps):
  1. Swipe down from the top-right corner to open Control Center.
  2. Touch and hold an empty area, then tap Add a Control. (Or tap +.)
  3. Search for Cali Care, tap Log, then tap an empty area to
     finish.
- Action Button (iPhones that have one): Settings › Action Button ›
  Controls › Log.

Capturing the assets
- Simulator: the `DesignReview` scheme's UI tests drive Springboard and
  save screenshots (StepAssetTests, ControlCenterStepTests,
  WidgetReviewTests).
- Real device only (the human records these): Action Button, Siri.
- Blur or remove any personal content in captures.

## 8. Motion and feedback
- Illustrations draw themselves in (about 1 second) every time their
  screen appears or the app comes back to the front, then stop. They never
  loop; only onboarding may keep a gentle hand-drawn wobble.
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
shape: our tokens, sans throughout, 12pt inner corners.

- Every log button has a clear tap affordance: a filled 12pt tile with the
  palm and "Log" under it, centered.
- Small (158 × 158): the Log tile (logs without opening the app, an
  interactive widget) and "Last: 1:52 AM". After a tap: "Logged ·
  2:14 AM" with an Undo button (44pt) for 5 seconds.
- Medium (338 × 158): "Last night: 2 wake-ups" by day, "Tonight: 2
  wake-ups" from 7 PM; the Log tile (primary); Flare (logs instantly) and
  Note (opens the app's note sheet; a widget can't take typing); "Last
  1:52 AM".
- Lock Screen circular (72 × 72): the palm over "Log".
- Lock Screen rectangular (160 × 72): "Tonight: 2" (or "Last night: 2")
  over "Last 1:52 AM".
- Control (Control Center and the Lock Screen): the palm and "Log". Its
  name in the controls gallery is "Log" (search "Cali Care" finds it). It can be assigned to the Action Button.

Looks (iOS 27, as since iOS 26): Home Screen widgets render full color,
tinted, and clear, each in light and dark. Full color uses our palette
(night palette in dark). Tinted and clear have no fills of their own:
content becomes one tint or white on glass. Itchy stays the most
prominent element: its tile keeps a stronger glass fill while Flare and
Note become outlines. Hierarchy otherwise comes from size and weight, and every piece of text stays at least 4.5:1 on the
glass over the wallpaper. Lock Screen widgets and controls are always
monochrome on dark glass.

## 12. Definition of done for any UI task
- Uses only tokens and type styles from DesignSystem.swift.
- Checked against section 2, and you've said which items you checked.
- Screenshots of the screen in day and night, and at the largest Dynamic
  Type size, saved to /design-review/<task>/ and listed in your report.
- Contrast test passes.
- VoiceOver reads every control with a clear label.
