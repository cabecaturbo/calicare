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
        content.containerBackground(entry.palette.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        let palette = entry.palette
        if let feedback = entry.feedback {
            HStack(spacing: Spacing.m) {
                LoggedLabel(feedback: feedback, palette: palette)
                Spacer(minLength: 0)
                UndoButton(palette: palette)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let child = entry.childEntity {
            let snapshot = entry.snapshot
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(child.name)
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    LogButton(action: .itchy, child: child, detail: "\(snapshot.itchCount) today", palette: palette)
                    LogButton(
                        action: .roughNight, child: child,
                        detail: WidgetText.night(snapshot.lastNight), palette: palette
                    )
                    LogButton(
                        action: .bowelMovement, child: child,
                        detail: "\(snapshot.bowelMovementCount) today", palette: palette
                    )
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
