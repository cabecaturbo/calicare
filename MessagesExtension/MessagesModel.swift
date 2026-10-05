import Core
import Foundation
import Observation

/// This week's card for each child, read from the shared store. Read-only;
/// needs no network.
@MainActor
@Observable
final class MessagesModel {
    private(set) var cards: [WeeklyCard] = []
    /// "Last night: 3 wake-ups, at …" for each child, as plain text to send.
    private(set) var lastNights: [LastNightText] = []
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
        let day = LogPeriod.lastNight(at: now)
        var nights: [LastNightText] = []
        for child in children {
            let events = (try? await LogStore(modelContainer: container).events(for: day, child: child.id)) ?? []
            let text = LogPeriod(kind: .night, day: day, events: events).words.shareText { CardClock.time($0) }
            nights.append(LastNightText(childName: child.name, text: children.count > 1 ? "\(child.name). \(text)" : text))
        }
        lastNights = nights
    }
}

struct LastNightText: Identifiable {
    let childName: String
    let text: String
    var id: String { childName }
}
