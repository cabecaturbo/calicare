import Core
import SwiftUI

/// "Logged · 2:14 AM" with Undo, on an oat bar above Itchy. Leaves after 5 seconds.
/// VoiceOver hears the full sentence ("Logged itchy spell for Cal, 2:14 AM.").
struct LoggedBanner: View {
    @Environment(\.palette) private var palette
    let confirmation: TodayModel.Confirmation
    /// Only for a flare: opens the body outline.
    var onAddWhere: (() -> Void)?
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            Text(confirmation.short)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(confirmation.text)
            if let onAddWhere {
                Button("Add where", action: onAddWhere)
                    .buttonStyle(.textLink)
                    .accessibilityHint("Mark where the flare was.")
            }
            Button("Undo", action: onUndo)
                .buttonStyle(.textLink)
                .fontWeight(.semibold)
                .accessibilityHint("Removes what you just logged.")
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x2)
        .frame(minHeight: 52)
        .paperBackground(.oat)
        .clipShape(RoundedRectangle(cornerRadius: Corner.control))
        .task(id: confirmation.id) {
            AccessibilityNotification.Announcement(confirmation.text).post()
            // A little longer when there's "Add where" to reach.
            try? await Task.sleep(for: .seconds(onAddWhere == nil ? 5 : 7))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
