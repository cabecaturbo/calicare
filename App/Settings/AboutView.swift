import Core
import SwiftUI

/// Settings › How Cali Care works: what each thing you log means, in plain
/// words, and what the app doesn't do.
struct AboutView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("Cali Care organizes the plan your child's provider gave you and keeps a simple log of how things are going, so you can see it and share it. It never recommends treatments and doesn't diagnose anything. Not medical advice.")
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("What you log")
                        .textStyle(.section)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    fact("Skin today", "Your one answer each evening: calm, a little itchy, flaring, or very rough. It's the only thing Progress uses for skin.")
                    fact("Last night", "Good, okay, or rough, as you saw it. Without a rating, the number of itchy wake-ups stands in.")
                    fact("Log (the palm)", "One tap each time it itches. Between 7 PM and 7 AM it counts as an itchy wake-up.")
                    fact("Flare, bowel movement, mood, note", "Whenever they're worth noting. \"Add where\" after a flare is optional.")
                    fact("Routine", "The steps you set in Plan, ticked off as you go.")
                }

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("How Progress compares")
                        .textStyle(.section)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Only with your child's own history: this week against last week, this month against last month. Days with nothing logged are left out, never counted as bad. \"Worth watching\" means something changed; it never says why.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A day runs 7 PM to 7 PM, so a night belongs to the morning after it.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x5)
        }
        .paperBackground()
        .navigationTitle("How Cali Care works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fact(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(title)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Text(detail)
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
