import Core
import SwiftUI
import WidgetKit

/// Home Screen: one big "Itchy" button plus the last itch time.
/// Lock Screen (circular): an itch button.
struct ItchWidget: Widget {
    static let kind = "ItchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: CareProvider()) { entry in
            ItchWidgetView(entry: entry)
        }
        .configurationDisplayName("Itchy")
        .description("One tap logs an itchy moment.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct ItchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CareEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular.containerBackground(Color.clear, for: .widget)
        default:
            small.containerBackground(entry.palette.paper, for: .widget)
        }
    }

    /// The Itchy tile (logs without opening the app) and the last itch time.
    /// After a tap: "Logged", the time, and Undo.
    @ViewBuilder
    private var small: some View {
        let palette = entry.palette
        if let feedback = entry.feedback {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                LoggedLabel(feedback: feedback, palette: palette)
                Spacer(minLength: 0)
                UndoButton(palette: palette)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let child = entry.childEntity {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                ItchyTile(child: child, palette: palette)
                Text(WidgetText.last(entry.snapshot.lastItch, by: entry.snapshot.lastItchBy, now: entry.date))
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else {
            AddChildPrompt(palette: palette)
        }
    }

    /// The Lock Screen draws its own tint: a plus over the word.
    @ViewBuilder
    private var circular: some View {
        if entry.feedback != nil {
            // Not a button, so a second tap can't undo by accident.
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Logged")
        } else if let child = entry.childEntity {
            Button(intent: WidgetLogIntent(action: .itchy, child: child)) {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                        Text("Itchy")
                            .font(TypeStyle.body.font)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WidgetAction.itchy.accessibilityLabel(for: child.name))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Text("Itchy")
                    .font(TypeStyle.body.font)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityLabel("Add your child in Cali Care to start logging")
        }
    }
}

#Preview("Small", as: .systemSmall) {
    ItchWidget()
} timeline: {
    CareEntry.sample(at: .now)
}

#Preview("Circular", as: .accessoryCircular) {
    ItchWidget()
} timeline: {
    CareEntry.sample(at: .now)
}
