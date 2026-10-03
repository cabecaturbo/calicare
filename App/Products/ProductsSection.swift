import Core
import SwiftUI

/// Plan's Products: a count and the way into the product diary.
struct ProductsSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Products")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            NavigationLink {
                ProductListView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Product diary").textStyle(.body).foregroundStyle(palette.ink)
                        Text(summary).textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.graphite)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
            }
            .buttonStyle(.plain)
        }
    }

    /// "3 in use · 1 never again", or a line saying what it's for.
    private var summary: String {
        guard !model.products.isEmpty else { return "Creams, washes, laundry, clothing" }
        let inUse = model.products.filter(\.inUse).count
        let never = model.products.filter(\.neverAgain).count
        return ["\(inUse) in use", never > 0 ? "\(never) never again" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}
