import Core
import SwiftUI

/// The onboarding setup steps, all on one page, for later.
struct QuickLoggingGuideView: View {
    @Environment(\.palette) private var palette
    @State private var childName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                WidgetSetupGuide(childName: childName)
                SiriSetupGuide()
                ActionButtonSetupGuide()
            }
            .padding(Spacing.l)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Quick logging")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            childName = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).currentChild()?.name
        }
    }
}
