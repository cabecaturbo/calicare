#if DEBUG
import Core

/// Debug builds only: adds a sample child so Siri, Shortcuts, and Control Center
/// have someone to log for before onboarding exists.
enum DebugSeed {
    static func addSampleChildIfNeeded() async {
        do {
            let store = ChildStore(modelContainer: try CaliCareModelContainer.shared())
            guard try await store.activeChildren().isEmpty else { return }
            try await store.addChild(name: "Cal", colorTag: "sage")
        } catch {
            print("DebugSeed failed: \(error)")
        }
    }
}
#endif
