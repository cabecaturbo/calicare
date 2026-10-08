import Core
import SwiftUI

/// "Logged itchy spell for Cal, 2:14 AM. · Undo" on an oat sheet. Leaves after 4 seconds.
struct LoggedBanner: View {
    @Environment(\.palette) private var palette
    let confirmation: TodayModel.Confirmation
    /// Only for a flare: opens the body outline.
    var onAddWhere: (() -> Void)?
    let onUndo: () -> Void
    let onDismiss: () -> Void
    /// Done: the check draws as the banner arrives.
    @State private var marked = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x3) {
            DoneMark(isDone: marked, size: 22)
            Text(confirmation.text)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onAddWhere {
                Button("Add where", action: onAddWhere)
                    .buttonStyle(.textLink)
                    .accessibilityHint("Mark where the flare was.")
            }
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
            marked = false
            try? await Task.sleep(for: .milliseconds(1))
            marked = true
            AccessibilityNotification.Announcement(confirmation.text).post()
            // A little longer when there's "Add where" to reach.
            try? await Task.sleep(for: .seconds(onAddWhere == nil ? 4 : 6))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
