import Core
import SwiftUI

/// "This week.": one thin block per day in the skin scale colors, day letters
/// under it, today outlined. A day not answered is a dashed outline, never "missed".
struct WeekStrip: View {
    @Environment(\.palette) private var palette
    let days: [WeekDay]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("This week.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
            HStack(spacing: Spacing.x2) {
                ForEach(days) { day in
                    let today = day.id == days.last?.id
                    VStack(spacing: Spacing.x1 + 2) {
                        block(day.skin)
                            .overlay {
                                if today {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(palette.ink, lineWidth: 2)
                                        .padding(-4)
                                }
                            }
                        Text(day.day.noon().formatted(.dateTime.weekday(.narrow)))
                            .textStyle(.meta)
                            .fontWeight(today ? .semibold : .regular)
                            .foregroundStyle(today ? palette.ink : palette.graphite)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week. " + days.map(description).joined(separator: " "))
    }

    @ViewBuilder
    private func block(_ skin: SkinToday?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        if let skin {
            shape.fill(palette.color(for: skin))
                .overlay(shape.strokeBorder(palette.graphite, lineWidth: 1))
                .frame(height: 14)
        } else {
            shape.strokeBorder(palette.graphite, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(height: 14)
        }
    }

    /// "Tuesday: skin flaring." or "Today: not answered yet."
    private func description(_ day: WeekDay) -> String {
        let name = day.id == days.last?.id ? "Today" : day.day.noon().formatted(.dateTime.weekday(.wide))
        guard let skin = day.skin else { return "\(name): not answered." }
        return "\(name): skin \(skin.words)."
    }
}
