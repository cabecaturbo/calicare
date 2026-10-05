import Core
import SwiftUI

/// The core action: one-tap log rows, then last night's rating. Rows, not tiles;
/// each label is a word a tired parent reads instantly.
struct LogButtons: View {
    @Environment(\.palette) private var palette
    let isDaytime: Bool
    let entries: [LogEntry]
    let lastNight: LastNightReport?
    let onLog: (LogType, LogValue?) -> Void

    private struct Choice: Identifiable {
        let type: LogType
        let title: String
        let spoken: String
        var id: LogType { type }
    }

    private static let choices = [
        Choice(type: .itchEpisode, title: "Itchy", spoken: "Log itching"),
        Choice(type: .flare, title: "Flare", spoken: "Log a flare"),
        Choice(type: .bowelMovement, title: "Bowel movement", spoken: "Log a bowel movement"),
        Choice(type: .routineDone, title: "Routine done", spoken: "Log routine done"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            LedgerSection("Log") {
                ForEach(Self.choices) { choice in
                    logRow(choice)
                }
            }
            LedgerSection(isDaytime ? "How was last night?" : "How's the night going?") {
                ForEach(NightRating.allCases, id: \.self) { rating in
                    ratingRow(rating)
                }
            }
        }
    }

    private func logRow(_ choice: Choice) -> some View {
        let count = entries.filter { $0.type == choice.type }.count
        let countText = count > 0 ? "\(count) \(isDaytime ? "today" : "tonight")" : nil
        return Button {
            onLog(choice.type, value(for: choice.type))
        } label: {
            LedgerRow {
                Text(choice.title)
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            } trailing: {
                if let countText {
                    Text(countText)
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            }
        }
        .buttonStyle(.ledger)
        .accessibilityLabel(choice.spoken)
        .accessibilityValue(countText ?? "")
    }

    private func ratingRow(_ rating: NightRating) -> some View {
        let selected = isRated(rating)
        return Button {
            onLog(.nightRating, .night(rating))
        } label: {
            LedgerRow {
                Text(rating.title)
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            } trailing: {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.regular))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.ledger(isSelected: selected))
        .accessibilityLabel("Log a \(rating.rawValue) night")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Only marks the night these rows log to: this morning's by day, tonight's in the evening.
    private func isRated(_ rating: NightRating) -> Bool {
        guard let lastNight, isDaytime || lastNight.isTonight else { return false }
        return lastNight.rating == rating
    }

    private func value(for type: LogType) -> LogValue? {
        type == .routineDone ? .routine(RoutineTime.likely(at: .now)) : nil
    }
}
