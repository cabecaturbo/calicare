import Core
import SwiftUI
import WidgetKit

/// Lock Screen (rectangular): last night's rating.
struct LastNightWidget: Widget {
    static let kind = "LastNightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: CareProvider()) { entry in
            LastNightWidgetView(entry: entry)
        }
        .configurationDisplayName("Last night")
        .description("How last night went, at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LastNightWidgetView: View {
    let entry: CareEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Last night")
                .font(TypeStyle.meta.font)
                .foregroundStyle(.secondary)
            Text(WidgetText.night(entry.snapshot.lastNight))
                .font(TypeStyle.lede.font)
                .widgetAccentable()
            if let name = entry.snapshot.child?.name {
                Text(name)
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(.secondary)
            }
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
