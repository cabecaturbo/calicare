import Core
import SwiftUI
import WidgetKit

/// Lock Screen (rectangular): tonight's (or last night's) wake-ups and the last itch.
struct LastNightWidget: Widget {
    static let kind = "LastNightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: CareProvider()) { entry in
            LastNightWidgetView(entry: entry)
        }
        .configurationDisplayName("Last night")
        .description("Tonight's wake-ups and the last itch, at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LastNightWidgetView: View {
    let entry: CareEntry

    var body: some View {
        let snapshot = entry.snapshot
        VStack(alignment: .leading, spacing: 1) {
            Text("\(snapshot.isNight ? "Tonight" : "Last night"): \(snapshot.nightWakeUps)")
                .font(TypeStyle.control.font)
                .widgetAccentable()
            Text(WidgetText.last(snapshot.lastItch, now: entry.date))
                .font(TypeStyle.meta.font)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .containerBackground(Color.clear, for: .widget)
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LastNightWidget()
} timeline: {
    CareEntry.sample(at: .now)
}
