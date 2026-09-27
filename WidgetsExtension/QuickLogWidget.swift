import Core
import SwiftUI
import WidgetKit

/// Home Screen (medium): Itchy, Rough night, Bowel movement, Routine done.
struct QuickLogWidget: Widget {
    static let kind = "QuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectChildIntent.self, provider: CareProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick log")
        .description("One tap for itching, a rough night, a bowel movement, or a done routine.")
        .supportedFamilies([.systemMedium])
    }
}

struct QuickLogWidgetView: View {
    let entry: CareEntry

    var body: some View {
        content.containerBackground(entry.palette.paper, for: .widget)
    }

    /// A small ledger: the child's name, then four words with today's counts.
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
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(child.name)
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
                    .lineLimit(1)
                WidgetRule(palette: palette)
                HStack(spacing: Spacing.x3) {
                    LogButton(action: .itchy, child: child, detail: "\(snapshot.itchCount) today", palette: palette)
                    WidgetRule(palette: palette, vertical: true)
                    LogButton(
                        action: .roughNight, child: child,
                        detail: WidgetText.night(snapshot.lastNight), palette: palette
                    )
                }
                WidgetRule(palette: palette)
                HStack(spacing: Spacing.x3) {
                    LogButton(
                        action: .bowelMovement, child: child,
                        detail: "\(snapshot.bowelMovementCount) today", palette: palette
                    )
                    WidgetRule(palette: palette, vertical: true)
                    LogButton(action: .routineDone, child: child, detail: "\(snapshot.routinesDone) today", palette: palette)
                }
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
