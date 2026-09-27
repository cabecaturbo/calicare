import Core
import SwiftUI

extension View {
    /// The header every tab shares: Settings top-right, and on Plan and Progress
    /// the child switcher top-left. Today puts the name in its content instead.
    func shellToolbar(showsSwitcher: Bool) -> some View {
        modifier(ShellToolbarModifier(showsSwitcher: showsSwitcher))
    }
}

private struct ShellToolbarModifier: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell
    let showsSwitcher: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsSwitcher {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarLeading) {
                            ChildSwitcher(style: .navigationBar)
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            ChildSwitcher(style: .navigationBar)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shell.showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.regular))
                            .foregroundStyle(palette.graphite)
                    }
                    .accessibilityLabel("Settings")
                }
            }
    }
}
