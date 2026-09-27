import Core
import SwiftUI

extension View {
    /// "Logged, 2:14 AM · Undo" at the bottom of the tab that's showing.
    func logConfirmation(on tab: AppTab) -> some View {
        modifier(LogConfirmationModifier(tab: tab))
    }
}

private struct LogConfirmationModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    let tab: AppTab

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                // Only the visible tab shows it, so it's announced and timed once.
                if shell.tab == tab, let confirmation = model.confirmation {
                    LoggedBanner(confirmation: confirmation) {
                        Task { await model.undo(confirmation) }
                    } onDismiss: {
                        model.confirmation = nil
                    }
                    .padding(.horizontal, Spacing.x4)
                    .padding(.bottom, Spacing.x2)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.confirmation)
    }
}
