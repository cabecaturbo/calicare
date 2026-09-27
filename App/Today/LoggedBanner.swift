import Core
import SwiftUI

/// "Logged itchy spell for Cal, 2:14 AM. · Undo" on an oat sheet. Leaves after 4 seconds.
struct LoggedBanner: View {
    @Environment(\.palette) private var palette
    let confirmation: TodayModel.Confirmation
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            Text(confirmation.text)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo", action: onUndo)
                .buttonStyle(.textLink)
                .accessibilityHint("Removes what you just logged.")
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x2)
        .frame(minHeight: Size.row(isNight: palette.isNight))
        .paperBackground(.oat)
        .clipShape(RoundedRectangle(cornerRadius: Corner.control))
        .task(id: confirmation.id) {
            AccessibilityNotification.Announcement(confirmation.text).post()
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
