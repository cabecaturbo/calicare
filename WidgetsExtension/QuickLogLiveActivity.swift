import ActivityKit
import AppIntents
import Core
import SwiftUI
import WidgetKit

/// The Quick Log card on the Lock Screen and in the Dynamic Island: a big Log
/// button and only a count and times (the Lock Screen is public). When its
/// period ends it shows a short summary and Log keeps working; if its 8 hours
/// run out first, it says so instead of quietly going away.
struct QuickLogLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickLogCardAttributes.self) { context in
            let palette = Self.palette(context.state)
            QuickLogCardView(context: context, palette: palette)
                .activityBackgroundTint(palette.paper)
                .activitySystemActionForegroundColor(palette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Quick Log").font(TypeStyle.label.font)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.itches.count)")
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel(QuickLogCardView.spoken(context.state))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CardLogButton(childID: context.attributes.childID, palette: Palette.night, wide: true)
                }
            } compactLeading: {
                Image(systemName: "hand.raised.fill").accessibilityLabel("Quick Log")
            } compactTrailing: {
                Text("\(context.state.itches.count)")
                    .accessibilityLabel(QuickLogCardView.spoken(context.state))
            } minimal: {
                Text("\(context.state.itches.count)")
                    .accessibilityLabel(QuickLogCardView.spoken(context.state))
            }
            .widgetURL(DeepLink.quickLog)
        }
    }

    /// Night colors for the night, day colors for the day.
    static func palette(_ state: QuickLogCardAttributes.ContentState) -> Palette {
        state.kind == .night ? .night : .day
    }
}

private struct QuickLogCardView: View {
    let context: ActivityViewContext<QuickLogCardAttributes>
    let palette: Palette

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text("Quick Log")
                    .font(TypeStyle.title.font)
                    .foregroundStyle(palette.ink)
                status
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if context.state.justLogged != nil, !context.isStale {
                Button(intent: QuickLogCardUndoIntent()) {
                    Text("Undo")
                        .font(.headline)
                        .foregroundStyle(palette.accent)
                        .frame(minWidth: 72, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo the last log")
            } else {
                CardLogButton(childID: context.attributes.childID, palette: palette, wide: false)
            }
        }
        .padding(Spacing.x4)
        .widgetURL(context.isStale && context.state.endsEarlyAt == nil && context.state.kind == .night ? DeepLink.night : DeepLink.quickLog)
    }

    @ViewBuilder private var status: some View {
        let words = context.state.words
        if context.isStale, let ended = context.state.endsEarlyAt {
            Text("Ended at \(CardClock.time(ended)). Tap Log to keep going.")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
        } else if context.isStale {
            Text(words.summary { CardClock.shortTime($0) })
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
        } else if let logged = context.state.justLogged {
            Text("Logged \(CardClock.time(logged))")
                .font(TypeStyle.body.font.weight(.semibold))
                .foregroundStyle(palette.ink)
        } else {
            Text(words.line { CardClock.time($0) })
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
                .accessibilityLabel(Self.spoken(context.state))
        }
    }

    static func spoken(_ state: QuickLogCardAttributes.ContentState) -> String {
        state.words.spokenLine { CardClock.time($0) }
    }
}

/// The big Log button, matching the Home Screen widget: a rose capsule
/// with a soft shade and the palm. Never red: rose is the accent.
private struct CardLogButton: View {
    let childID: UUID
    let palette: Palette
    let wide: Bool

    var body: some View {
        Button(intent: QuickLogCardLogIntent(childID: childID)) {
            HStack(spacing: Spacing.x2) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 17, weight: .medium))
                Text("Log")
                    .font(.custom("NewsreaderDisplay-Medium", size: 20, relativeTo: .title3))
            }
            .foregroundStyle(palette.paper)
            .padding(.horizontal, Spacing.x5)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: 56)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [palette.accent.mix(with: .white, by: 0.08), palette.accent.mix(with: .black, by: 0.06)],
                    startPoint: .top, endPoint: .bottom
                ))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log itching")
    }
}
