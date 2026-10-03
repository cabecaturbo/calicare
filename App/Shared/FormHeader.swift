import Core
import SwiftUI

/// A form or list section header: the serif section style, sentence case.
struct FormHeader: View {
    @Environment(\.palette) private var palette
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .textStyle(.section)
            .foregroundStyle(palette.ink)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}
