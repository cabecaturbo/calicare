import SwiftUI

/// Side by side normally; stacked at accessibility text sizes, so a name
/// and the status beside it never squeeze each other into broken words.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 8
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout(content)
    }
}
