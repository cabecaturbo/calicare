# Notebook redesign: design review

Captured September 26, 2026 on the iPhone 17 simulator (iOS 27) by the
`DesignReview` scheme's UI tests. Half-size JPEGs.

- `day/`: day palette, default text size.
- `night/`: night palette (pinned with `-designReviewNight YES`).
- `xxxl/`: day palette at the largest accessibility text size.
- `steps/`: the raw captures behind the VisualSteps assets, plus `tap-spots.txt`.

Screens in each folder:

| File | Screen |
|---|---|
| 01–06 | Onboarding: welcome, add child, Home Screen widget, Lock Screen widget, Siri, Action Button |
| 07 | Today before the first log |
| 08 | The log confirmation ("Logged … · Undo") |
| 09 | The one-time reminders offer |
| 10–12 | Today with logs, scrolled through the timeline and week |
| 13 | Edit a log |
| 14–15 | Settings |
| 16 | Recent logs (debug list) |
| 17 | Quick logging guide |
| 20–22 | Home Screen widgets, the widget's "Logged" state, Lock Screen widgets |

Night has no `21`: the widget was still showing "Logged" from the day capture.
