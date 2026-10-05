import SwiftUI

/// The compact Messages bubble: the week, three stats, and a nudge to tap
/// for the full card. 600 × 360 points, day palette, fixed type sizes.
public struct WeeklyBubbleView: View {
    public static let size = CGSize(width: 600, height: 360)

    let card: WeeklyCard
    private let palette = Palette.day

    public init(card: WeeklyCard) {
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(card.childName) · \(card.dateRange)")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
            Text(card.headline)
                .font(TypeStyle.title.font)
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, Spacing.x1)
            palette.ink.frame(height: Rule.width)
                .padding(.top, CardSpacing.row)

            if card.hasSummary {
                HStack(alignment: .top, spacing: 0) {
                    stat("\(card.goodNights)", "good nights of 7")
                    stat("\(card.itchyWakeUps)", "itchy wake-ups")
                    stat("\(card.routineDays)", "days with routines")
                }
                .padding(.top, Spacing.margin)
            } else {
                Text("Log a few more days and this card fills in.")
                    .font(TypeStyle.body.font)
                    .foregroundStyle(palette.graphite)
                    .padding(.top, Spacing.margin)
            }

            Spacer(minLength: 0)
            HStack {
                Text("Tap to see full week.")
                    .font(TypeStyle.control.font)
                    .foregroundStyle(palette.accent)
                Spacer()
                Text("Not medical advice.")
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
            }
        }
        .padding(Spacing.margin)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(palette.paper)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(value)
                .font(TypeStyle.display.font)
                .monospacedDigit()
                .foregroundStyle(palette.ink)
            Text(label)
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
