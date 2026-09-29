import Core
import SwiftUI

/// Bottom bar options, switchable in Settings › Debug so the owner can try
/// each on the phone before we pick one.
enum BottomBarStyle: String, CaseIterable, Identifiable {
    /// Our own pills: tabs on the left, Itchy and ••• on the right.
    case pills
    /// Apple's glass tab bar, with a slim logging row above it.
    case glassRow
    /// Apple's glass tab bar, with Itchy as a separate round button.
    case glassCircle

    static let key = "bottomBarStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pills: "Pills (current)"
        case .glassRow: "Glass bar + logging row"
        case .glassCircle: "Glass bar + Itchy circle"
        }
    }

    /// The glass options need iOS 26; older phones keep the pills.
    var isAvailable: Bool {
        if #available(iOS 26.1, *) { return true }
        return self == .pills
    }
}

/// The logging row above the glass tab bar: "+ Itchy" and •••. Hidden on
/// Today at night, where the big Itchy button is on the page.
@available(iOS 26.0, *)
struct LogAccessory: View {
    @Environment(\.palette) private var palette
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(TodayModel.self) private var model

    var body: some View {
        HStack(spacing: Spacing.x3) {
            Button {
                Task { await model.log(.itchEpisode) }
            } label: {
                HStack(spacing: Spacing.x2) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Itchy")
                        .font(.system(size: 17, weight: .semibold))
                    if placement != .inline, let last = model.entries.first(where: { $0.type == .itchEpisode }) {
                        Text("Last \(model.time(last.timestamp))")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.graphite)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(palette.ink)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log itching")
            MoreLogMenu {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: Size.touchTarget, height: Size.touchTarget)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Spacing.x4)
        .disabled(model.child == nil)
    }
}

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
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.confirmation)
    }

    private func addWhere(for confirmation: TodayModel.Confirmation) -> (() -> Void)? {
        guard confirmation.entry.type == .flare, !confirmation.wasDeleted else { return nil }
        return {
            model.confirmation = nil
            shell.addingWhere = confirmation.entry
        }
    }
}
