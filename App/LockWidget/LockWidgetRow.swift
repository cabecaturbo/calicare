import Core
import SwiftUI

/// Today: "Add the Log widget to your Lock Screen", opening the guide. Shows
/// only while no Cali Care widget is on the Lock Screen.
struct LockWidgetRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Shell.self) private var shell
    @State private var needed = false

    var body: some View {
        // A VStack, not a Group: an empty Group drops its modifiers, and the check never runs.
        VStack(spacing: 0) {
            if needed {
                Button {
                    shell.showingLockGuide = true
                } label: {
                    Label("Add the Log widget to your Lock Screen", systemImage: "hand.raised")
                        .font(TypeStyle.label.font)
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                }
                .accessibilityHint("Shows the steps.")
                .padding(.top, Spacing.x4)
                .transition(Motion.fade)
            }
        }
        .task(id: scenePhase) { await check() }
        .onChange(of: shell.showingLockGuide) { _, showing in
            if !showing { Task { await check() } }
        }
    }

    private func check() async {
        guard scenePhase == .active else { return }
        let onLockScreen = await LockWidgetStatus.isOnLockScreen()
        withMotion(.quick) { needed = !onLockScreen }
    }
}
