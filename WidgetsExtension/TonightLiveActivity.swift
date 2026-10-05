import ActivityKit
import AppIntents
import Core
import SwiftUI
import WidgetKit

/// "Tonight" on the Lock Screen and in the Dynamic Island: the night palette,
/// a big Log button, and only a count and times (the Lock Screen is public).
/// Stale at 7 AM it becomes last night's summary; if its 8 hours ran out
/// first, it says so instead of quietly going away.
struct TonightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TonightAttributes.self) { context in
            TonightCard(context: context)
                .activityBackgroundTint(Palette.night.paper)
                .activitySystemActionForegroundColor(Palette.night.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Tonight").font(TypeStyle.label.font)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.wakeUps.count)")
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel(TonightCard.spoken(context.state))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.isStale {
                        LogButton(childID: context.attributes.childID, compact: false)
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.fill").accessibilityLabel("Tonight")
            } compactTrailing: {
                Text("\(context.state.wakeUps.count)")
                    .accessibilityLabel(TonightCard.spoken(context.state))
            } minimal: {
                Text("\(context.state.wakeUps.count)")
                    .accessibilityLabel(TonightCard.spoken(context.state))
            }
            .widgetURL(DeepLink.tonight)
        }
    }
}

private struct TonightCard: View {
    let context: ActivityViewContext<TonightAttributes>
    private let palette = Palette.night

    var body: some View {
        Group {
            if context.isStale {
                stale
            } else {
                live
            }
        }
        .padding(Spacing.x4)
        .widgetURL(context.isStale && context.state.endsEarlyAt == nil ? DeepLink.night : DeepLink.tonight)
    }

    private var live: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text("Tonight")
                    .font(TypeStyle.title.font)
                    .foregroundStyle(palette.ink)
                if let logged = context.state.justLogged {
                    Text("Logged \(TonightClock.time(logged))")
                        .font(TypeStyle.body.font.weight(.semibold))
                        .foregroundStyle(palette.ink)
                } else {
                    Text(Self.line(context.state))
                        .font(TypeStyle.body.font)
                        .foregroundStyle(palette.graphite)
                        .accessibilityLabel(Self.spoken(context.state))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if context.state.justLogged != nil {
                Button(intent: TonightUndoIntent()) {
                    Text("Undo")
                        .font(.headline)
                        .foregroundStyle(palette.indigo)
                        .frame(minWidth: 72, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo the last wake-up")
            } else {
                LogButton(childID: context.attributes.childID, compact: true)
            }
        }
    }

    @ViewBuilder private var stale: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            if let ended = context.state.endsEarlyAt {
                Text("Tonight ended at \(TonightClock.time(ended)).")
                    .font(TypeStyle.body.font.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text("Open Cali Care to keep logging.")
                    .font(TypeStyle.body.font)
                    .foregroundStyle(palette.graphite)
            } else {
                Text(Self.summary(context))
                    .font(TypeStyle.body.font.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text("Tap to see and share last night.")
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    static func line(_ state: TonightAttributes.ContentState) -> String {
        NightWords(wakeUps: state.wakeUps).line { TonightClock.time($0) }
    }

    static func spoken(_ state: TonightAttributes.ContentState) -> String {
        NightWords(wakeUps: state.wakeUps).spokenLine { TonightClock.time($0) }
    }

    static func summary(_ context: ActivityViewContext<TonightAttributes>) -> String {
        NightWords(wakeUps: context.state.wakeUps).summary { TonightClock.shortTime($0) }
    }
}

/// The big Log button: indigo on the night paper, never red.
private struct LogButton: View {
    let childID: UUID
    let compact: Bool
    private let palette = Palette.night

    var body: some View {
        Button(intent: TonightLogIntent(childID: childID)) {
            Label("Log", systemImage: "hand.raised.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.paper)
                .padding(.horizontal, Spacing.x5)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 56)
                .background(palette.indigo, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a wake-up")
    }
}
