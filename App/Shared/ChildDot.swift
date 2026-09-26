import Core
import SwiftUI

/// A child's color tag as a small dot with a thin outline.
struct ChildDot: View {
    @Environment(\.palette) private var palette
    let color: ChildColor
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .fill(color.color)
            .overlay(Circle().strokeBorder(palette.muted.opacity(0.4), lineWidth: 1))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
