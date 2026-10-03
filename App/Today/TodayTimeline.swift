import Core
import SwiftUI

/// Today's logs, newest first. Tap one to change or delete it.
struct TodayTimeline: View {
    @Environment(\.palette) private var palette
    let model: TodayModel
    let isDaytime: Bool
    let onEdit: (LogEntry) -> Void

    var body: some View {
        LedgerSection(
            isDaytime ? "Today" : "Tonight",
            footnote: model.entries.isEmpty ? nil : "Tap a log to change or delete it."
        ) {
            if model.entries.isEmpty {
                Text(isDaytime
                    ? "Nothing logged yet today. Tap a row above whenever something happens."
                    : "Nothing logged yet tonight.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x4)
            } else {
                ForEach(model.entries) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        let title = model.title(for: entry)
        let time = model.time(entry.timestamp)
        let source = entry.source.label
        let byline = model.byline(for: entry)
        return Button {
            onEdit(entry)
        } label: {
            LedgerRow {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(title)
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                    if let note = entry.note {
                        Text(note)
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                            .lineLimit(3)
                    }
                }
            } trailing: {
                Text([time, source, byline].compactMap { $0 }.joined(separator: " · "))
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .multilineTextAlignment(.trailing)
            }
        }
        .buttonStyle(.ledger)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, time, entry.note, source, byline].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Edit or delete")
        .accessibilityAddTraits(.isButton)
    }
}

extension EntrySource {
    /// Where a log came from, when it wasn't this screen.
    var label: String? {
        switch self {
        case .app: nil
        case .widget: "Widget"
        case .intent: "Siri or Shortcuts"
        case .notification: "Reminder"
        case .watch: "Watch"
        }
    }
}
