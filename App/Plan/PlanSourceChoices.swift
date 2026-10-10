import Core
import SwiftUI

/// The three ways to bring in a plan, and what happens to it. Shared by
/// onboarding and the empty Plan tab so the privacy line never drifts.
struct PlanSourceChoices: View {
    @Environment(\.palette) private var palette
    let onAdd: (AddPlanSheet.Source) -> Void

    static let title = "Bring in your care plan"
    static let line = "Scan the pages, add the PDF, or pick photos you already took. You check every step before it starts."
    /// True to the code: the file is read on this phone; only its text goes to
    /// parse-care-plan (and on to the AI); started steps sync to the account.
    static let privacy = "To read a plan, sign in with Apple. The file stays on your phone. Only its words are sent, to be read by AI. Steps you start are saved to your account."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                SourceRow(title: "Scan with the camera", symbol: "camera.viewfinder") { onAdd(.scan) }
                SourceRow(title: "Add a PDF", symbol: "doc") { onAdd(.file) }
                SourceRow(title: "Choose photos you took", symbol: "photo.on.rectangle") { onAdd(.photos) }
            }
            Text(Self.privacy)
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.x3)
        }
    }
}
