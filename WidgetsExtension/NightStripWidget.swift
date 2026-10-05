import Core
import SwiftUI
import WidgetKit

/// Home Screen (small and medium): recent nights as rows of dots, one dot per
/// wake-up along 7 PM to 7 AM. Read only; tapping opens Progress.
struct NightStripWidget: Widget {
    static let kind = "NightStripWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: NightStripProvider()) { entry in
            NightStripWidgetView(entry: entry)
        }
        .configurationDisplayName("Night strip")
        .description("Your recent nights at a glance: one dot for each wake-up.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NightStripEntry: TimelineEntry {
    let date: Date
    /// Nil until a child is added.
    let strip: NightStrip?

    var palette: Palette { Palette.current(at: date) }

    static func sample(at date: Date, nights: Int) -> NightStripEntry {
        let calendar = Calendar.autoupdatingCurrent
        let today = CareDay.containing(date, calendar: calendar)
        var events: [LogEntry] = []
        let pattern: [[Int]] = [[23, 2], [1], [], [22, 1, 4], [3], [0], [23, 3]]
        for back in 0..<nights {
            let night = today.adding(days: -back, calendar: calendar).nightInterval(calendar: calendar)
            for hour in pattern[back % pattern.count] {
                let offset = Double((hour - 19 + 24) % 24) * 3600
                events.append(LogEntry(childID: UUID(), type: .itchEpisode, timestamp: night.start.addingTimeInterval(offset)))
            }
        }
        return NightStripEntry(date: date, strip: NightStrip(events: events, count: nights, now: date, calendar: calendar))
    }
}

/// Entries for now and for the 7 AM, 7 PM, and 8 PM changes, so the newest
/// row and the palette roll over on time. Logs reload all timelines.
struct NightStripProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NightStripEntry {
        .sample(at: .now, nights: Self.nights(context.family))
    }

    func snapshot(for configuration: SelectChildIntent, in context: Context) async -> NightStripEntry {
        if context.isPreview { return .sample(at: .now, nights: Self.nights(context.family)) }
        return await entries(childID: configuration.child?.id, family: context.family, now: .now).first
            ?? .sample(at: .now, nights: Self.nights(context.family))
    }

    func timeline(for configuration: SelectChildIntent, in context: Context) async -> Timeline<NightStripEntry> {
        Timeline(entries: await entries(childID: configuration.child?.id, family: context.family, now: .now), policy: .atEnd)
    }

    static func nights(_ family: WidgetFamily) -> Int { family == .systemSmall ? 5 : 7 }

    private func entries(childID: UUID?, family: WidgetFamily, now: Date) async -> [NightStripEntry] {
        do {
            let source = try WidgetDataSource.live()
            guard let child = try await source.child(for: childID) else {
                return [NightStripEntry(date: now, strip: nil)]
            }
            var entries: [NightStripEntry] = []
            for date in WidgetTimeline.dates(from: now, feedback: nil) {
                let strip = try await source.nightStrip(for: child, at: date, count: Self.nights(family))
                entries.append(NightStripEntry(date: date, strip: strip))
            }
            return entries
        } catch {
            return [NightStripEntry(date: now, strip: nil)]
        }
    }
}

struct NightStripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NightStripEntry

    var body: some View {
        content
            .containerBackground(entry.palette.paper, for: .widget)
            .widgetURL(DeepLink.progress)
    }

    @ViewBuilder
    private var content: some View {
        let palette = entry.palette
        if let strip = entry.strip, !strip.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(family == .systemSmall ? "Nights" : "Last \(strip.nights.count) nights")
                    .font(TypeStyle.meta.font.weight(.semibold))
                    .foregroundStyle(palette.graphite)
                VStack(spacing: family == .systemSmall ? 5 : 3) {
                    ForEach(strip.nights) { night in
                        NightRow(night: night, showsLabel: family == .systemMedium, palette: palette)
                    }
                }
                .frame(maxHeight: .infinity)
                if family == .systemMedium {
                    HStack {
                        Text("7 PM")
                        Spacer(minLength: 0)
                        Text("7 AM")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(palette.graphite)
                    .padding(.leading, NightRow.labelWidth + Spacing.x2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strip.accessibilitySummary())
        } else {
            Text(NightStrip.emptyText)
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityLabel(NightStrip.emptyText)
        }
    }
}

/// One night: a light track (tinted by that day's skin answer when there is
/// one) and a dot for each wake-up where it happened along the night.
private struct NightRow: View {
    static let labelWidth: CGFloat = 30
    @Environment(\.widgetRenderingMode) private var renderingMode
    let night: NightStrip.Night
    let showsLabel: Bool
    let palette: Palette

    var body: some View {
        HStack(spacing: Spacing.x2) {
            if showsLabel {
                Text(night.isTonight ? "Now" : NightStrip.shortWeekday(night.day))
                    .font(.system(size: 11, weight: night.isTonight ? .semibold : .regular))
                    .foregroundStyle(palette.graphite)
                    .frame(width: Self.labelWidth, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule().fill(palette.hairline).frame(height: 1)
                    ForEach(Array(night.positions.enumerated()), id: \.offset) { _, position in
                        Circle()
                            .fill(palette.accent)
                            .frame(width: Self.dot, height: Self.dot)
                            .offset(x: (proxy.size.width - Self.dot) * position)
                            .widgetAccentable()
                    }
                }
                .frame(height: proxy.size.height)
            }
        }
    }

    private static let dot: CGFloat = 7

    /// Light, so the dots stay the main thing. Clear in tinted and clear modes.
    private var track: Color {
        guard renderingMode == .fullColor, let skin = night.skin else { return .clear }
        return palette.color(for: skin).opacity(0.35)
    }
}

#Preview("Medium", as: .systemMedium) {
    NightStripWidget()
} timeline: {
    NightStripEntry.sample(at: .now, nights: 7)
}

#Preview("Small", as: .systemSmall) {
    NightStripWidget()
} timeline: {
    NightStripEntry.sample(at: .now, nights: 5)
}
