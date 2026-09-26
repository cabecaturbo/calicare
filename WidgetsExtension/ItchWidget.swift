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
            small.containerBackground(entry.palette.background, for: .widget)
        }
    }

    @ViewBuilder
    private var small: some View {
        let palette = entry.palette
        if let feedback = entry.feedback {
            VStack(alignment: .leading, spacing: Spacing.s) {
                LoggedLabel(feedback: feedback, palette: palette)
                Spacer(minLength: 0)
                UndoButton(palette: palette)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let child = entry.childEntity {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                LogButton(action: .itchy, child: child, detail: nil, palette: palette, prominent: true)
                Text(WidgetText.lastItch(entry.snapshot.lastItch, now: entry.date))
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } else {
            AddChildPrompt(palette: palette)
        }
    }

    @ViewBuilder
    private var circular: some View {
        if entry.feedback != nil {
            // Not a button, so a second tap can't undo by accident.
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Logged")
        } else if let child = entry.childEntity {
            Button(intent: WidgetLogIntent(action: .itchy, child: child)) {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "hand.raised")
                            .font(.title3.weight(.medium))
                        Text("Itchy")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WidgetAction.itchy.accessibilityLabel(for: child.name))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "hand.raised")
            }
            .accessibilityLabel("Add your child in CaliCare to start logging")
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
