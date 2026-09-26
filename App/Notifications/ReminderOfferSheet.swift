import Core
import SwiftUI

/// A short, friendly explanation before the system permission prompt.
struct ReminderOfferSheet: View {
    @Environment(\.palette) private var palette
    let onTurnOn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Image(systemName: "bell")
                .font(.title2)
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)

            Text("A gentle nudge, if you'd like")
                .font(Typography.title2)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)

            Text("CaliCare can ask how last night went, and remind you about morning and evening routines. Answer right from the notification. No need to open the app.")
                .font(Typography.body)
                .foregroundStyle(palette.ink)

            Text("Skip one anytime. Change times or turn them off in Settings.")
                .font(Typography.callout)
                .foregroundStyle(palette.muted)

            Spacer(minLength: Spacing.s)

            Button(action: onTurnOn) {
                Text("Turn on reminders")
                    .font(Typography.button)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
                    .background(palette.accent, in: Capsule())
            }

            Button(action: onNotNow) {
                Text("Not now")
                    .font(Typography.button)
                    .foregroundStyle(palette.sageDark)
                    .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
            }
        }
        .padding(Spacing.l)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
