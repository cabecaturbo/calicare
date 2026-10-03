import Core
import SwiftUI

/// The one lede sentence about last night, e.g. "A rough night, 3 itchy wake-ups."
struct LastNightLede: View {
    @Environment(\.palette) private var palette
    let report: LastNightReport

    var body: some View {
        Text(report.sentence)
            .textStyle(.lede)
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(report.heading). \(report.sentence)")
    }
}
