import Core
import SwiftUI

/// A quiet way in: a small icon, a name, a light chevron. No card.
struct SourceRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(palette.graphite)
                    .frame(width: 24)
                Text(title).textStyle(.body).foregroundStyle(palette.ink)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.graphite.opacity(0.7))
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// The star (DESIGN.md §5a) as a heading: one serif phrase and up to two
/// short lines on a soft card. Plan without a plan, and every onboarding step.
struct SoftStar: View {
    @Environment(\.palette) private var palette
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(title)
                .textStyle(.statement)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(line)
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.star))
    }
}
