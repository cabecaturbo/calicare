import Core
import SwiftUI

/// Onboarding until it's finished once, then Today.
struct RootView: View {
    @AppStorage(OnboardingFlag.key) private var hasOnboarded = false
    @State private var start: OnboardingView.Step?

    var body: some View {
        Group {
            if let review = Self.reviewStep {
                OnboardingView(start: review) {}
            } else if hasOnboarded {
                AppShell()
            } else if let start {
                OnboardingView(start: start) { hasOnboarded = true }
            } else {
                Color.clear.paperBackground()
            }
        }
        .task { await chooseStart() }
    }

    /// Design review only: `-designReviewOnboarding welcome|child|reminders|logAnywhere`.
    private static var reviewStep: OnboardingView.Step? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "designReviewOnboarding") {
        case "welcome": return .welcome
        case "child": return .child
        case "reminders": return .reminders
        case "logAnywhere": return .logAnywhere
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// Someone who already added a child (and left mid-setup) picks up at reminders.
    private func chooseStart() async {
        guard !hasOnboarded, start == nil else { return }
        let children = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).activeChildren()
        start = (children?.isEmpty ?? true) ? .welcome : .reminders
    }
}

enum OnboardingFlag {
    static let key = "hasFinishedOnboarding"
}
