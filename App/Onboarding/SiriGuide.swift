import AppIntents
import Core
import SwiftUI

/// "Log itching in Cali Care", with Apple's own Siri tip instead of steps.
struct SiriSetupGuide: View {
    @Environment(\.palette) private var palette
    @State private var showTip = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Ask Siri",
                detail: "Nothing to set up. Just say it, even with your hands full or the phone locked."
            )
            VStack(alignment: .leading, spacing: Spacing.x4) {
                SiriTipView(intent: LogItchIntent(), isVisible: $showTip)
                    .siriTipViewStyle(palette.isNight ? .dark : .light)
                Text("Also try \u{201C}Log a rough night in Cali Care\u{201D} or \u{201C}Undo in Cali Care.\u{201D}")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.margin)
        }
    }
}

private struct GuideHeading: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.titleToLede) {
            Text(title)
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.margin)
    }
}
