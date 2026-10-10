import Core
import SwiftUI
import WidgetKit

/// Home Screen (medium): last night or tonight, Itchy, Flare, and Note.
struct QuickLogWidget: Widget {
    static let kind = "QuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: CareProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Log and note")
        .description("One tap for itching or a flare, and a quick way to a note.")
        .supportedFamilies([.systemMedium])
    }
}

struct QuickLogWidgetView: View {
    let entry: CareEntry

    var body: some View {
        content.containerBackground(entry.palette.paper, for: .widget)
    }

    /// "Last night: 2 wake-ups" (or "Tonight"), the Itchy tile, then Flare and Note.
    @ViewBuilder
    private var content: some View {
        let palette = entry.palette
        if let feedback = entry.feedback {
            HStack(alignment: .center, spacing: Spacing.x4) {
                LoggedLabel(feedback: feedback, palette: palette)
                Spacer(minLength: 0)
                UndoButton(palette: palette)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let child = entry.childEntity {
            let snapshot = entry.snapshot
            HStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(WidgetText.wakeUps(snapshot.nightWakeUps, isNight: snapshot.isNight))
                        .contentTransition(.numericText())
                        .font(TypeStyle.control.font)
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ItchyTile(child: child, palette: palette)
                }
                VStack(spacing: Spacing.x2) {
                    FlareButton(child: child, palette: palette)
                    NoteLink(palette: palette)
                    Text(WidgetText.last(snapshot.lastItch, now: entry.date))
                        .font(TypeStyle.meta.font)
                        .foregroundStyle(palette.graphite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 104)
            }
        } else {
            AddChildPrompt(palette: palette)
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    QuickLogWidget()
} timeline: {
    CareEntry.sample(at: .now)
}
