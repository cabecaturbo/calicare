import ActivityKit
import Core
import SwiftUI
import WidgetKit

/// Phase 0 test: the Lock Screen and Dynamic Island for the test Live Activity.
/// Night palette, a big Log button, a count and times only.
struct LockScreenTestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockScreenTestAttributes.self) { context in
            let palette = Palette.night
            HStack(spacing: Spacing.x4) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("Lock Screen test")
                        .font(TypeStyle.label.font)
                        .foregroundStyle(palette.graphite)
                    Text(Self.line(context.state))
                        .font(TypeStyle.body.font)
                        .foregroundStyle(palette.ink)
                }
                Spacer(minLength: 0)
                Button(intent: LockScreenTestLogIntent()) {
                    Label("Log", systemImage: "hand.raised.fill")
                        .font(.headline)
                        .foregroundStyle(palette.paper)
                        .padding(.horizontal, Spacing.x5)
                        .frame(minHeight: 52)
                        .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log a wake-up")
            }
            .padding(Spacing.x4)
            .activityBackgroundTint(palette.paper)
            .activitySystemActionForegroundColor(palette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(Self.line(context.state)).font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: LockScreenTestLogIntent()) {
                        Label("Log", systemImage: "hand.raised.fill")
                    }
                    .accessibilityLabel("Log a wake-up")
                }
            } compactLeading: {
                Image(systemName: "hand.raised.fill")
            } compactTrailing: {
                Text("\(context.state.count)")
            } minimal: {
                Text("\(context.state.count)")
            }
        }
    }

    static func line(_ state: LockScreenTestAttributes.ContentState) -> String {
        guard let last = state.last else { return "No taps yet." }
        let time = last.formatted(date: .omitted, time: .shortened)
        return state.count == 1 ? "1 tap · last at \(time)" : "\(state.count) taps · last at \(time)"
    }
}
