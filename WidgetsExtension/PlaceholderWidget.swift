import Core
import SwiftUI
import WidgetKit

/// Temporary widget so the extension builds. Replaced by logging widgets in Prompt 4.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlaceholderWidget", provider: PlaceholderProvider()) { entry in
            PlaceholderWidgetView(entry: entry)
        }
        .configurationDisplayName("CaliCare")
        .description("One-tap logging is coming soon.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    /// One entry now and one when night mode flips, so the palette switches on time.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        let now = Date.now
        let next = NightMode.nextChange(after: now)
        let entries = [PlaceholderEntry(date: now), PlaceholderEntry(date: next)]
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

struct PlaceholderWidgetView: View {
    let entry: PlaceholderEntry

    var body: some View {
        let palette = Palette.current(at: entry.date)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("CaliCare")
                .font(Typography.title3)
                .foregroundStyle(palette.ink)
            Text("One-tap logging is coming soon.")
                .font(Typography.caption)
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(palette.background, for: .widget)
    }
}
