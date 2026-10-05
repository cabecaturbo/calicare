import SwiftUI

/// The weekly report card (DESIGN.md §10): a page from a small magazine.
/// 600 × 750 points, always the day palette, no paper grain, and fixed type
/// sizes so the shared image looks the same everywhere.
public struct WeeklyCardView: View {
    public static let size = CGSize(width: 600, height: 750)

    let card: WeeklyCard
    private let palette = Palette.day

    public init(card: WeeklyCard) {
        self.card = card
    }

    public init(report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) {
        self.init(card: WeeklyCard(report: report, calendar: calendar))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wordmark over a hairline ink rule.
            Text("Cali Care")
                .font(TypeStyle.title.font)
                .foregroundStyle(palette.ink)
            palette.ink.frame(height: Rule.width)
                .padding(.top, Spacing.x2)

            Text(card.headline)
                .font(TypeStyle.display.font)
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, CardSpacing.block)
            Text("\(card.childName) · \(card.dateRange)")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
                .padding(.top, Spacing.x1)

            WeekChart(days: card.days, palette: palette)
                .padding(.top, CardSpacing.block)

            if card.hasSummary {
                VStack(spacing: 0) {
                    palette.hairline.frame(height: Rule.width)
                    row("Good nights", "\(card.goodNights)", detail: "of 7")
                    row("Itchy wake-ups", "\(card.itchyWakeUps)",
                        detail: card.itchyWakeUpsLastWeek.map { "\($0) last week" })
                    row("Routines done", "\(card.routineDays)", detail: "of \(card.daysWithLogs) days")
                    row("Bowel movements", "\(card.bowelMovements)", detail: nil)
                    if let mood = card.usualMood {
                        row("Usual mood", mood, detail: nil)
                    }
                }
                .padding(.top, Spacing.margin)
            } else {
                Text("Log a few more days and this card fills in.")
                    .font(TypeStyle.body.font)
                    .foregroundStyle(palette.graphite)
                    .padding(.top, Spacing.margin)
            }

            if let line = card.worthWatching {
                Text(line)
                    .font(TypeStyle.body.font)
                    .foregroundStyle(palette.ochre)
                    .padding(.top, Spacing.x4)
            }

            Spacer(minLength: 0)
            Text("Cali Care · Not medical advice.")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
        }
        .padding(Spacing.margin)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(palette.paper)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }

    private func row(_ label: String, _ value: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CardSpacing.row) {
            Text(label)
                .font(TypeStyle.control.font)
                .foregroundStyle(palette.ink)
            Spacer(minLength: Spacing.x4)
            Text(value)
                .font(TypeStyle.title.font)
                .monospacedDigit()
                .foregroundStyle(palette.ink)
            if let detail {
                Text(detail)
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
                    .frame(width: 104, alignment: .leading)
            } else {
                Color.clear.frame(width: 104, height: 1)
            }
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

/// Seven night dots and seven skin bars on the accent scale. Empty days are outlines.
private struct WeekChart: View {
    let days: [WeeklyCard.Day]
    let palette: Palette

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: CardSpacing.row) {
                label("Nights").frame(height: 18)
                label("Skin").frame(height: 40, alignment: .bottom)
                label(" ")
            }
            .frame(width: 72, alignment: .leading)
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: CardSpacing.row) {
                    mark(Circle(), level: day.night.flatMap(CareLevel.init(rawValue:))).frame(width: 18, height: 18)
                    bar(step: day.skin).frame(height: 40, alignment: .bottom)
                    label(day.letter)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(TypeStyle.meta.font)
            .foregroundStyle(palette.graphite)
    }

    @ViewBuilder
    private func mark(_ shape: some InsettableShape, level: CareLevel?) -> some View {
        if let level {
            shape.fill(palette.color(for: level))
        } else {
            shape.strokeBorder(palette.graphite.opacity(0.5), lineWidth: 1)
        }
    }

    /// Taller and deeper for harder days (accent steps 1–5); an outline when not answered.
    @ViewBuilder
    private func bar(step: Int?) -> some View {
        let shape = RoundedRectangle(cornerRadius: Corner.image)
        if let step, (1...5).contains(step) {
            shape.fill(palette.severity(step: step))
                .frame(width: 18, height: CGFloat(8 + 6 * step))
        } else {
            shape.strokeBorder(palette.graphite.opacity(0.5), lineWidth: 1)
                .frame(width: 18, height: 14)
        }
    }
}
