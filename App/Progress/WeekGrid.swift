import Core
import SwiftUI

/// This week as one aligned grid (DESIGN.md §3, UX.md §6): a column per day
/// with the skin bar on top (height and depth both say how rough), the night
/// dot below, and the day letter underneath. Not answered is a short dash.
struct WeekGrid: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let days: [WeekDay]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            let heading = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.x1))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            heading {
                Text("This week")
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { Spacer() }
                Text("\(days.filter { $0.nightRating == .good }.count) good nights of \(days.count)")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            Grid(horizontalSpacing: Spacing.x2, verticalSpacing: Spacing.x2) {
                GridRow(alignment: .bottom) {
                    Text("Skin").textStyle(.meta).foregroundStyle(palette.graphite).gridColumnAlignment(.leading)
                    ForEach(days) { day in
                        Group {
                            if let skin = day.skin {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(palette.color(for: skin))
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(palette.graphite, lineWidth: 1))
                                    .frame(width: 18, height: CGFloat(8 + 13 * skin.step))
                            } else {
                                Capsule().fill(palette.graphite).frame(width: 12, height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .bottom)
                    }
                }
                GridRow {
                    Text("Night").textStyle(.meta).foregroundStyle(palette.graphite)
                    ForEach(days) { day in
                        Group {
                            if let night = day.night {
                                Circle()
                                    .fill(palette.color(for: night))
                                    .overlay(Circle().strokeBorder(palette.graphite, lineWidth: 1))
                            } else {
                                Capsule().fill(palette.graphite).frame(width: 12, height: 2)
                            }
                        }
                        .frame(width: 14, height: 14)
                        .frame(maxWidth: .infinity)
                    }
                }
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        Text(day.day.noon().formatted(.dateTime.weekday(.narrow)))
                            .font(index == days.count - 1 ? TypeStyle.meta.font.weight(.semibold) : TypeStyle.meta.font)
                            .foregroundStyle(index == days.count - 1 ? palette.indigo : palette.graphite)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            HStack(spacing: Spacing.x2) {
                Text("Calm")
                ForEach(SkinToday.allCases, id: \.self) { SkinSwatch(answer: $0, size: 12) }
                Text("Very rough")
                Capsule().fill(palette.graphite).frame(width: 12, height: 2).padding(.leading, Spacing.x2)
                Text("Not answered")
            }
            .textStyle(.meta)
            .foregroundStyle(palette.graphite)
            .accessibilityHidden(true)
        }
    }

    private var summary: String {
        days.map { day in
            let name = day.day.noon().formatted(.dateTime.weekday(.wide))
            let skin = day.skin.map { "skin \($0.words)" } ?? "skin not answered"
            let night = day.nightRating.map { "\($0.rawValue) night" } ?? "night not rated"
            return "\(name): \(skin), \(night)"
        }.joined(separator: ". ")
    }
}
