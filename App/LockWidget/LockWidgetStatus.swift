import Core
import SwiftUI
import WidgetKit

/// Whether the parent already has the Log widget (or Last night) on their Lock
/// Screen, so Today only offers the guide to people who need it.
enum LockWidgetStatus {
    /// Set when the Lock Screen guide is finished with Done.
    static let guideFinishedKey = "lockGuideFinished"

    private static let kinds: Set<String> = ["ItchWidget", "LastNightWidget"]
    private static let lockFamilies: Set<WidgetFamily> = [.accessoryCircular, .accessoryRectangular, .accessoryInline]

    /// True when one of our widgets is on the Lock Screen. If iOS can't say,
    /// falls back to whether the guide was finished.
    static func isOnLockScreen() async -> Bool {
        do {
            let configs = try await WidgetCenter.shared.currentConfigurations()
            return configs.contains { kinds.contains($0.kind) && lockFamilies.contains($0.family) }
        } catch {
            return UserDefaults.standard.bool(forKey: guideFinishedKey)
        }
    }
}
