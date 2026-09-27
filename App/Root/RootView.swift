import Core
import SwiftUI

/// Onboarding until it's finished once, then Today.
struct RootView: View {
    @AppStorage(OnboardingFlag.key) private var hasOnboarded = false
    @State private var start: OnboardingView.Step?

    var body: some View {
        Group {
            if hasOnboarded {
                TodayView()
            } else if let start {
                OnboardingView(start: start) { hasOnboarded = true }
            } else {
                Color.clear.paperBackground()
            }
        }
        .task { await chooseStart() }
    }

    /// Someone who already added a child (and left mid-setup) picks up at quick logging.
    private func chooseStart() async {
        guard !hasOnboarded, start == nil else { return }
        let children = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).activeChildren()
        start = (children?.isEmpty ?? true) ? .welcome : .quickLogging
    }
}

enum OnboardingFlag {
    static let key = "hasFinishedOnboarding"
}
