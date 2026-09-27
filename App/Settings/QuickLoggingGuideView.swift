import Core
import SwiftUI

/// The onboarding setup steps, all on one page, for later.
struct QuickLoggingGuideView: View {
    @State private var childName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                WidgetSetupGuide(childName: childName)
                LockScreenSetupGuide()
                SiriSetupGuide()
                ActionButtonSetupGuide()
                ControlCenterSetupGuide()
            }
            .padding(.vertical, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle("Quick logging")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            childName = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).currentChild()?.name
        }
    }
}
