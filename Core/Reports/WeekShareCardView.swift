import SwiftUI

/// The "Share this week" picture: 600 × 580 pt, rendered at 3x for a text.
/// In Messages it shows about 250 pt wide, so nothing is smaller than 22 pt.
/// Always the day look, even at night. The skin squares use their own blue
/// scale, made to read at that size (an exception to the olive scale; see DESIGN.md).
public struct WeekShareCardView: View {
    public static let size = CGSize(width: 600, height: 580)

    let card: WeekShareCard

    public init(card: WeekShareCard) {
        self.card = card
    }

    enum Ink {
        static let background = Color(hex: 0xF6F1E8)
        static let strong = Color(hex: 0x1E1B18)
        static let soft = Color(hex: 0x5C554D)
    }

    /// Calm, A little itchy, Flaring, Very rough.
    static func fill(_ skin: SkinToday) -> Color {
        switch skin {
        case .calm: Color(hex: 0xE3E7EE)
        case .littleItchy: Color(hex: 0xC2CBDB)
        case .flaring: Color(hex: 0x56698F)
        case .veryRough: Color(hex: 0x2E3E5E)
        }
    }

    private static let serif = "NewsreaderDisplay-Medium"

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(card.headline)
                .font(.custom(Self.serif, fixedSize: 62))
                .lineSpacing(0)
                .foregroundStyle(Ink.strong)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            squares
                .padding(.top, 36)
            legend
                .padding(.top, 12)
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 8) {
                if let nights = card.nightsLine {
                    Text(nights)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Ink.strong)
                }
                if let watch = card.worthWatching {
                    Text(watch)
                        .font(.system(size: 30))
                        .foregroundStyle(Ink.strong)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 44)
        .padding(.horizontal, 48)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Ink.background)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("\(card.childName) · \(card.rangeLabel)")
                .font(.system(size: 26, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text("Cali Care")
                .font(.custom(Self.serif, fixedSize: 24))
                .fixedSize()
        }
        .foregroundStyle(Ink.soft)
    }

    private var squares: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(card.days) { day in
                    square(day.skin)
                }
            }
            HStack(spacing: 10) {
                ForEach(card.days) { day in
                    Text(day.label)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Ink.soft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func square(_ skin: SkinToday?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        return Group {
            if let skin {
                shape.fill(Self.fill(skin))
                    .overlay(shape.strokeBorder(Ink.soft, lineWidth: 2))
            } else {
                shape.strokeBorder(Ink.soft, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("Calm")
            ForEach(SkinToday.allCases, id: \.self) { skin in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Self.fill(skin))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Ink.soft, lineWidth: 2))
                    .frame(width: 24, height: 24)
            }
            Text("Rough")
        }
        .font(.system(size: 24))
        .foregroundStyle(Ink.soft)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

extension WeekShareCard {
    /// Sample weeks for previews and the render check. Not shown to parents.
    public static func sample(
        name: String = "Cal",
        headline: String = "A calmer week",
        skins: [SkinToday?],
        nights: String? = "4 of 7 good nights.",
        watch: String? = "More flares."
    ) -> WeekShareCard {
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return WeekShareCard(
            childName: name,
            rangeLabel: "Sep 20–26",
            headline: headline,
            days: skins.enumerated().map { index, skin in
                Day(day: CareDay(year: 2026, month: 9, day: 20 + index), label: labels[index], skin: skin)
            },
            nightsLine: nights,
            worthWatching: watch
        )
    }
}

#Preview("Typical week", traits: .sizeThatFitsLayout) {
    WeekShareCardView(card: .sample(skins: [.littleItchy, .flaring, .littleItchy, .calm, .calm, .calm, .calm], watch: nil))
}

#Preview("All calm", traits: .sizeThatFitsLayout) {
    WeekShareCardView(card: .sample(skins: Array(repeating: .calm, count: 7), nights: "7 of 7 good nights.", watch: nil))
}

#Preview("Rough week", traits: .sizeThatFitsLayout) {
    WeekShareCardView(card: .sample(headline: "A harder week", skins: [.flaring, .veryRough, .veryRough, .flaring, .flaring, .littleItchy, .veryRough], nights: "1 of 7 good nights.", watch: "Itchy wake-ups went up."))
}

#Preview("Two days unanswered", traits: .sizeThatFitsLayout) {
    WeekShareCardView(card: .sample(headline: "About the same as last week", skins: [.calm, nil, .littleItchy, nil, .calm, .littleItchy, .calm], watch: nil))
}

#Preview("Long name", traits: .sizeThatFitsLayout) {
    WeekShareCardView(card: .sample(name: "Maximilian Alexander", headline: "Not enough logs yet for a summary", skins: [nil, nil, nil, nil, .calm, .littleItchy, .calm], nights: nil, watch: nil))
}
