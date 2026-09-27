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

    /// One big word and the last-logged time. No icon.
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
            LogButton(
                action: .itchy, child: child,
                detail: WidgetText.lastItch(entry.snapshot.lastItch, now: entry.date),
                palette: palette, prominent: true
            )
        } else {
            AddChildPrompt(palette: palette)
        }
    }

    /// The Lock Screen draws its own tint, so this is just the word.
    @ViewBuilder
    private var circular: some View {
        if entry.feedback != nil {
            // Not a button, so a second tap can't undo by accident.
            ZStack {
                AccessoryWidgetBackground()
                Text("Logged")
                    .font(TypeStyle.meta.font.weight(.medium))
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Logged")
        } else if let child = entry.childEntity {
            Button(intent: WidgetLogIntent(action: .itchy, child: child)) {
                ZStack {
                    AccessoryWidgetBackground()
                    Text("Itchy")
                        .font(TypeStyle.control.font)
                        .minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WidgetAction.itchy.accessibilityLabel(for: child.name))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Text("Itchy")
                    .font(TypeStyle.control.font)
                    .minimumScaleFactor(0.7)
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
