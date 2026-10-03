import Core
import SwiftUI

/// The one hero per screen (DESIGN.md §5): surface fill, 12pt corners, a caption
/// eyebrow, a serif title, a muted caption, and an optional ink drawing.
struct SummaryCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let eyebrow: String
    let title: String
    var caption: String?
    var art: Illustration.Kind?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(eyebrow)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Text(title)
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption {
                    Text(caption)
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // At accessibility sizes the title needs the whole width.
            if let art, !typeSize.isAccessibilitySize {
                Illustration(kind: art)
            }
        }
        .padding(Spacing.x4)
        .frame(minHeight: 128)
        .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.card))
        .accessibilityElement(children: .combine)
    }
}
