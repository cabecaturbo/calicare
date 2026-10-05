import Core
import SwiftUI

/// The last 7 days: a dot for each night and a square for each day's skin, on the
/// accent scale. Days with nothing logged are plain outlines, never "missed".
struct WeekStrip: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let days: [WeekDay]

    private static let markRow: CGFloat = 22

    var body: some View {
        LedgerSection(
            "This week",
            footnote: "Lighter is calmer. An outline just means nothing was logged."
        ) {
            Group {
                if typeSize.isAccessibilitySize {
                    rows
                } else {
                    columns
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x4)
            .overlay(alignment: .bottom) { Hairline() }
        }
    }

    /// Side by side, with row labels on the left.
    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                Text(" ").textStyle(.meta)
                rowLabel("Night")
                rowLabel("Skin")
            }
            .accessibilityHidden(true)
            ForEach(days) { day in
                VStack(spacing: Spacing.x4) {
                    Text(weekdayLetter(day))
                        .textStyle(.meta)
                        .foregroundStyle(isToday(day) ? palette.accent : palette.graphite)
                    LevelMark(fill: day.night.map(palette.color(for:)), shape: .circle)
                        .frame(height: Self.markRow)
                    LevelMark(fill: day.skin.map(palette.color(for:)), shape: .square)
                        .frame(height: Self.markRow)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(description(day))
            }
        }
    }

    /// One day per row, for the largest text sizes.
    private var rows: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            ForEach(days) { day in
                HStack(alignment: .center, spacing: Spacing.x4) {
                    LevelMark(fill: day.night.map(palette.color(for:)), shape: .circle)
                    LevelMark(fill: day.skin.map(palette.color(for:)), shape: .square)
                    Text(description(day))
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(description(day))
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(.meta)
            .foregroundStyle(palette.graphite)
            .frame(minHeight: Self.markRow)
            .padding(.trailing, Spacing.x2)
    }

    private func isToday(_ day: WeekDay) -> Bool {
        day.id == days.last?.id
    }

    private func weekdayLetter(_ day: WeekDay) -> String {
        day.day.noon().formatted(.dateTime.weekday(.narrow))
    }

    /// "Tuesday: rough night, skin a little itchy." or "Tuesday: nothing logged."
    private func description(_ day: WeekDay) -> String {
        let name = isToday(day) ? "Today" : day.day.noon().formatted(.dateTime.weekday(.wide))
        var parts: [String] = []
        if let rating = day.nightRating {
            parts.append("\(rating.rawValue) night")
        } else if day.nightItches > 0 {
            parts.append(day.nightItches == 1 ? "1 itchy wake-up" : "\(day.nightItches) itchy wake-ups")
        }
        if let skin = day.skin {
            parts.append("skin \(skin.words)")
        }
        return parts.isEmpty ? "\(name): nothing logged." : "\(name): \(parts.joined(separator: ", "))."
    }
}

/// A filled accent mark, or a quiet outline when there's nothing (no log, or skin not answered).
private struct LevelMark: View {
    enum MarkShape { case circle, square }

    @Environment(\.palette) private var palette
    let fill: Color?
    let shape: MarkShape
    private let size: CGFloat = 16

    var body: some View {
        Group {
            switch shape {
            case .circle:
                mark(Circle())
            case .square:
                mark(RoundedRectangle(cornerRadius: Corner.image))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mark(_ outline: some InsettableShape) -> some View {
        if let fill {
            outline.fill(fill)
        } else {
            outline.strokeBorder(palette.graphite.opacity(0.5), lineWidth: 1)
        }
    }
}
