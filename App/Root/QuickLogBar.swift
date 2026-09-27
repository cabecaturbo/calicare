import Core
import SwiftUI

/// Plan and Progress: one big "Itchy" and "Log…" (the full log sheet), in the
/// thumb zone above the tab bar. Today doesn't need it; its Log section is the same thing.
struct QuickLogBar: View {
    enum Style {
        /// Inside the system's tab bar accessory (iOS 26.1+), which draws its own glass.
        case accessory
        /// A bar on paper above the tab bar, for older iOS.
        case inset
    }

    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    let style: Style

    var body: some View {
        switch style {
        case .accessory:
            HStack(spacing: 0) {
                Button(action: logItch) {
                    Text("Itchy")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Log itching")
                palette.hairline
                    .frame(width: Rule.width)
                    .padding(.vertical, Spacing.x2)
                    .accessibilityHidden(true)
                Button(action: openLog) {
                    Text("Log\u{2026}")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, Spacing.margin)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Log something else")
            }
            .buttonStyle(.plain)
            .disabled(model.child == nil)
        case .inset:
            HStack(spacing: Spacing.x3) {
                Button("Itchy", action: logItch)
                    .buttonStyle(.primary)
                    .accessibilityLabel("Log itching")
                Button("Log\u{2026}", action: openLog)
                    .buttonStyle(.secondary)
                    .fixedSize()
                    .accessibilityLabel("Log something else")
            }
            .disabled(model.child == nil)
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x3)
            .background {
                palette.paper
                    .overlay(alignment: .top) { Hairline(inset: 0) }
                    .ignoresSafeArea()
            }
        }
    }

    private func logItch() {
        Task { await model.log(.itchEpisode) }
    }

    private func openLog() {
        shell.showingLog = true
    }
}

extension View {
    /// The quick log bar as the tab bar's accessory, on iOS 26.1 and later.
    @ViewBuilder
    func quickLogAccessory(isEnabled: Bool) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled) {
                QuickLogBar(style: .accessory)
            }
        } else {
            self
        }
    }

    /// The quick log bar above the tab bar, on iOS before 26.1.
    @ViewBuilder
    func quickLogBarInset(isEnabled: Bool) -> some View {
        if #available(iOS 26.1, *) {
            self
        } else if isEnabled {
            safeAreaInset(edge: .bottom, spacing: 0) {
                QuickLogBar(style: .inset)
            }
        } else {
            self
        }
    }
}
