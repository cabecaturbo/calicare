import Core
import Foundation
import Observation

/// This week's card for each child, read from the shared store. Read-only;
/// needs no network.
@MainActor
@Observable
final class MessagesModel {
    private(set) var cards: [WeeklyCard] = []
    private(set) var hasLoaded = false
    /// A tapped bubble's card, shown full size.
    var opened: WeeklyCard?

    func load(now: Date = .now) async {
        defer { hasLoaded = true }
        guard let container = try? CaliCareModelContainer.shared(),
              let children = try? await ChildStore(modelContainer: container).activeChildren()
        else { return }
        let weekEnding = CareDay.containing(now)
        var loaded: [WeeklyCard] = []
        for child in children {
            if let report = try? await WeeklyReport.load(child: child, weekEnding: weekEnding, container: container) {
                loaded.append(WeeklyCard(report: report))
            }
        }
        cards = loaded
    }
}
