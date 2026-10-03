import Core
import SwiftUI

/// A child's color tag as a small dot with a hairline outline, so oat shows on paper.
struct ChildDot: View {
    @Environment(\.palette) private var palette
    let color: ChildColor
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(color.color(in: palette))
            .overlay(Circle().strokeBorder(palette.graphite.opacity(0.5), lineWidth: Rule.width))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
