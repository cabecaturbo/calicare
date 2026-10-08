import Core
import SwiftUI

/// A short, friendly explanation before the system permission prompt.
struct ReminderOfferSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let onTurnOn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A gentle nudge, if you'd like")
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Cali Care can ask how last night went, and remind you about morning and evening routines. Answer right from the notification. No need to open the app.")
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .padding(.top, Spacing.titleToLede)
                Text("Skip one anytime. Change times or turn them off in Settings.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .padding(.top, Spacing.x4)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.x2) {
                Button("Turn on reminders", action: onTurnOn)
                    .buttonStyle(.primary)
                Button("Not now", action: onNotNow)
                    .buttonStyle(.textLink)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x4)
            .padding(.bottom, Spacing.x2)
            .paperBackground(.oat)
        }
        .paperBackground(.oat)
        // Half height fits the words at normal sizes; large text needs the full sheet.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
}
