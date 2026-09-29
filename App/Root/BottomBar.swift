import Core
import SwiftUI

/// Fallback for phones before iOS 26.1 (newer phones use Apple's glass tab bar
/// with the round Log button). The tab pill, and the log control docked to
/// its right ("Log" and "More"), over a 48pt fade into
/// the page. The "Logged · Undo" line sits just above it.
struct BottomBar: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell

    /// Content scrolls under the bar with this much room at the bottom.
    static let clearance: CGFloat = 120

    var body: some View {
        VStack(spacing: Spacing.x2) {
            if let confirmation = model.confirmation {
                LoggedBanner(confirmation: confirmation, onAddWhere: addWhere(for: confirmation)) {
                    Task { await model.undo(confirmation) }
                } onDismiss: {
                    model.confirmation = nil
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: Spacing.x3) {
                TabPill()
                LogPill(showsItchy: !(shell.tab == .today && palette.isNight))
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.x1)
        .background(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(colors: [palette.paper.opacity(0), palette.paper], startPoint: .top, endPoint: .bottom)
                    .frame(height: 48)
                palette.paper
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.25), value: model.confirmation)
    }

    /// "Add where" for a flare just logged.
    private func addWhere(for confirmation: TodayModel.Confirmation) -> (() -> Void)? {
        guard confirmation.entry.type == .flare, !confirmation.wasDeleted else { return nil }
        return {
            model.confirmation = nil
            shell.addingWhere = confirmation.entry
        }
    }
}

/// Today, Plan, Progress. The active tab is a surface pill with accent text by
/// day, an accent pill at night (the surface pill vanishes into the night bar).
private struct TabPill: View {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell

    private let tabs: [(AppTab, String, String)] = [
        (.today, "Today", "sun.horizon"),
        (.plan, "Plan", "list.bullet.clipboard"),
        (.progress, "Progress", "chart.line.uptrend.xyaxis"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab, title, symbol in
                let active = shell.tab == tab
                Button {
                    shell.tab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: symbol).font(.system(size: 18, weight: .regular))
                        Text(title).font(.system(size: 12, weight: active ? .semibold : .medium))
                    }
                    .foregroundStyle(active ? (palette.isNight ? palette.paper : palette.indigo) : palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background {
                        if active {
                            Capsule().fill(palette.isNight ? palette.indigo : palette.oat)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
        .background(palette.paper.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: Rule.width))
    }
}

/// One log control, the same on every tab: "Log" (one tap) and "More"
/// (Flare, Bowel movement, Mood, Note). Quieter than the active tab on purpose.
private struct LogPill: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    let showsItchy: Bool

    var body: some View {
        HStack(spacing: 2) {
            if showsItchy {
                Button {
                    Task { await model.log(.itchEpisode) }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "hand.raised.fill").font(.system(size: 12, weight: .semibold))
                        Text("Log").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(palette.ink)
                    .frame(width: 66)
                    .frame(maxHeight: .infinity)
                    .background(palette.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log itching")
            }
            MoreLogMenu {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: Size.touchTarget)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
        }
        .padding(6)
        .frame(height: 62)
        .background(palette.paper.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: Rule.width))
        .disabled(model.child == nil)
    }
}

/// Flare, Bowel movement, Mood, Note: the "•••" menu, wherever it sits.
struct MoreLogMenu<Label: View>: View {
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    @ViewBuilder let label: Label

    var body: some View {
        Menu {
            Button("Flare") { Task { await model.log(.flare) } }
            Button("Bowel movement") { shell.choosing = .bowel }
            Button("Mood") { shell.choosing = .mood }
            Button("Note") { shell.showingNote = true }
        } label: {
            label
        }
        .accessibilityLabel("More to log")
        .disabled(model.child == nil)
    }
}
