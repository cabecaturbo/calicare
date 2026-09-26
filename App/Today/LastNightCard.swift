import Core
import SwiftUI

/// One calm sentence about last night, e.g. "A rough night, 3 itchy wake-ups."
struct LastNightCard: View {
    @Environment(\.palette) private var palette
    let report: LastNightReport

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: "moon.stars")
                .font(.title2)
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(report.heading)
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                Text(report.sentence)
                    .font(Typography.title3)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
