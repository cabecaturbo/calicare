import Core
import SwiftUI

/// A month as a calendar (UX.md §6): weekday letters, then a cell per day with
/// the skin square (indigo depth says how rough) over the night dot. Not
/// answered is a short dash, the same as the week grid.
struct MonthGrid: View {
    @Environment(\.palette) private var palette
    let days: [WeekDay]
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text("This month")
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(days.filter { $0.nightRating == .good }.count) good nights of \(days.count)")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.x1), count: 7)
            LazyVGrid(columns: columns, spacing: Spacing.x2) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(days) { day in
                    cell(day)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            HStack(spacing: Spacing.x2) {
                Text("Skin")
                ForEach(SkinToday.allCases, id: \.self) { SkinSwatch(answer: $0, size: 12) }
                Text("· Night")
                Circle().fill(palette.color(for: CareLevel.low)).overlay(Circle().strokeBorder(palette.graphite, lineWidth: 1)).frame(width: 10, height: 10)
                Circle().fill(palette.color(for: CareLevel.high)).overlay(Circle().strokeBorder(palette.graphite, lineWidth: 1)).frame(width: 10, height: 10)
            }
            .textStyle(.meta)
            .foregroundStyle(palette.graphite)
            .accessibilityHidden(true)
        }
    }

    private func cell(_ day: WeekDay) -> some View {
        let isToday = day.day == CareDay.containing(.now)
        return VStack(spacing: 3) {
            Text("\(day.day.day)")
                .font(isToday ? TypeStyle.meta.font.weight(.semibold) : TypeStyle.meta.font)
                .foregroundStyle(isToday ? palette.indigo : palette.graphite)
            Group {
                if let skin = day.skin {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.color(for: skin))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(palette.graphite, lineWidth: 1))
                        .frame(width: 18, height: 18)
                } else {
                    Capsule().fill(palette.graphite).frame(width: 10, height: 2)
                }
            }
            .frame(height: 18)
            Group {
                if let night = day.night {
                    Circle()
                        .fill(palette.color(for: night))
                        .overlay(Circle().strokeBorder(palette.graphite, lineWidth: 1))
                        .frame(width: 10, height: 10)
                } else {
                    Capsule().fill(palette.graphite).frame(width: 10, height: 2)
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    /// Blank cells before the 1st, so days sit under their weekday.
    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first.day.noon())
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayLetters: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var summary: String {
        days.map { day in
            let name = day.day.noon().formatted(.dateTime.month(.wide).day())
            let skin = day.skin.map { "skin \($0.words)" } ?? "skin not answered"
            let night = day.nightRating.map { "\($0.rawValue) night" } ?? "night not rated"
            return "\(name): \(skin), \(night)"
        }.joined(separator: ". ")
    }
}
