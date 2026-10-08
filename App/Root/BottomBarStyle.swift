import Core
import SwiftUI

/// With the glass bar, the Logged · Undo line sits just above it, inside each tab.
struct LoggedBannerInset: ViewModifier {
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOn: Bool

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if isOn, let confirmation = model.confirmation {
                LoggedBanner(confirmation: confirmation, onAddWhere: addWhere(for: confirmation)) {
                    Task { await model.undo(confirmation) }
                } onDismiss: {
                    model.confirmation = nil
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, Spacing.x2)
                .transition(Motion.arriveTransition(reduceMotion: reduceMotion))
            }
        }
        .motion(.standard, value: model.confirmation)
    }

    private func addWhere(for confirmation: TodayModel.Confirmation) -> (() -> Void)? {
        guard confirmation.entry.type == .flare, !confirmation.wasDeleted else { return nil }
        return {
            model.confirmation = nil
            shell.addingWhere = confirmation.entry
        }
    }
}
