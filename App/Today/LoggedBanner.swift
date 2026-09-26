import Core
import SwiftUI

/// "Logged itchy spell for Cal, 2:14 PM" with Undo. Fades on its own.
struct LoggedBanner: View {
    @Environment(\.palette) private var palette
    let confirmation: TodayModel.Confirmation
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(confirmation.text)
                .font(Typography.callout)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onUndo) {
                Text("Undo")
                    .font(Typography.button)
                    .foregroundStyle(palette.sageDark)
                    .padding(.horizontal, Spacing.m)
                    .frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
                    .background(palette.sand, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Removes what you just logged.")
        }
        .padding(Spacing.s)
        .background(palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: .black.opacity(palette.isNight ? 0 : 0.08), radius: 12, y: 4)
        .task(id: confirmation.id) {
            AccessibilityNotification.Announcement(confirmation.text).post()
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
