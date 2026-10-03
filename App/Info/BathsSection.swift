import Core
import SwiftUI

/// Info › Care plan: the plan's baths, with this week's count (tap to log one), and its bath rules.
struct BathsSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let week: BathWeek

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Baths")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(week.rows) { row in
                    Button { Task { await model.logBath(row.item) } } label: {
                        AdaptiveStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.text).textStyle(.body).foregroundStyle(palette.ink)
                                let details = [row.item.frequency, row.item.duration].compactMap { $0 }
                                    .filter { !row.item.text.localizedCaseInsensitiveContains($0) }
                                if !details.isEmpty {
                                    Text(details.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(count(row))
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(row.item.text)")
                    .accessibilityValue(count(row))
                }
            }
            ForEach(week.notes, id: \.self) { note in
                Text(note).textStyle(.meta).foregroundStyle(palette.graphite)
            }
        }
    }

    /// "1 of 3 this week", or "1 this week" when the plan doesn't say how many.
    private func count(_ row: BathWeek.Row) -> String {
        row.perWeek.map { "\(row.doneThisWeek) of \($0) this week" } ?? "\(row.doneThisWeek) this week"
    }
}
