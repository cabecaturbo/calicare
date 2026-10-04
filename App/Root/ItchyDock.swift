import Core
import SwiftUI

/// Itchy's one home: a full-width ink button right above the tab bar, on every
/// tab, day and night, with "More" beside it. On Today at night Itchy grows to
/// 96pt and Flare and Note sit under it as big rows. The "Logged · 2:14 AM"
/// line with Undo shows above it after any log.
struct ItchyDock: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell

    /// Today at night: the biggest Itchy, with Flare and Note rows instead of More.
    let isNightToday: Bool

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
            HStack(spacing: Spacing.x2) {
                Button {
                    Task { await model.log(.itchEpisode) }
                } label: {
                    Text("Itchy")
                        .font(isNightToday ? .system(size: 28, weight: .semibold) : TypeStyle.band.font.weight(.semibold))
                        .foregroundStyle(palette.paper)
                        .frame(maxWidth: .infinity, minHeight: isNightToday ? 96 : 64)
                        .background(palette.ink, in: RoundedRectangle(cornerRadius: Corner.control))
                        .contentShape(RoundedRectangle(cornerRadius: Corner.control))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log itching")
                if !isNightToday {
                    Button("More") { shell.showingMore = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.indigo)
                        .padding(.horizontal, Spacing.x2)
                        .frame(minWidth: Size.touchTarget, minHeight: 64)
                        .contentShape(Rectangle())
                        .accessibilityHint("Flare, bowel movement, mood, or a note.")
                }
            }
            if isNightToday {
                VStack(spacing: 0) {
                    NightRow(title: "Flare", label: "Log a flare") { Task { await model.log(.flare) } }
                    NightRow(title: "Note", label: "Add a note") { shell.showingNote = true }
                }
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x3)
        .padding(.bottom, Spacing.x3)
        .background(palette.paper.ignoresSafeArea(edges: .horizontal))
        .disabled(model.child == nil)
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

/// A 72pt night row under Itchy: big words, a hairline under.
private struct NightRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.band)
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Puts the dock above the tab bar on a tab's screen.
struct ItchyDockInset: ViewModifier {
    var isNightToday = false

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            ItchyDock(isNightToday: isNightToday)
        }
    }
}

extension View {
    func itchyDock(isNightToday: Bool = false) -> some View {
        modifier(ItchyDockInset(isNightToday: isNightToday))
    }
}
