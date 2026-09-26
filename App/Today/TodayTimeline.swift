import Core
import SwiftUI

/// Today's logs, newest first. Tap one to change or delete it.
struct TodayTimeline: View {
    @Environment(\.palette) private var palette
    let model: TodayModel
    let isDaytime: Bool
    let onEdit: (LogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(isDaytime ? "Today" : "Tonight")
                .font(Typography.title2)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)

            if model.entries.isEmpty {
                Text(isDaytime
                    ? "Nothing logged yet today. Tap a button above whenever something happens."
                    : "Nothing logged yet tonight.")
                    .font(Typography.body)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(model.entries) { entry in
                        row(entry)
                        if entry.id != model.entries.last?.id {
                            Divider().overlay(palette.sand)
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .background(palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        let title = model.title(for: entry)
        let time = model.time(entry.timestamp)
        let source = entry.source.label
        return Button {
            onEdit(entry)
        } label: {
            HStack(alignment: .center, spacing: Spacing.m) {
                Image(systemName: entry.type.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(palette.ink)
                    if let note = entry.note {
                        Text(note)
                            .font(Typography.callout)
                            .foregroundStyle(palette.muted)
                            .lineLimit(3)
                    }
                    Text([time, source].compactMap { $0 }.joined(separator: " · "))
                        .font(Typography.caption)
                        .foregroundStyle(palette.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .frame(minHeight: TouchTarget.minimum + Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, time, entry.note, source].compactMap { $0 }.joined(separator: ", "))
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
