import Foundation

/// Patch tests from the care plan: how long the plan says to wait, and which
/// tests are running, ready to check, or done. Only what the plan says.
public struct PatchTests: Equatable, Sendable {
    public struct Test: Equatable, Sendable, Identifiable {
        public let entry: LogEntry
        /// "Calendula balm · inner forearm"
        public let label: String
        /// Started plus the plan's wait; nil when the plan doesn't say how long.
        public let checkAt: Date?
        public let result: PatchResult?
        public var id: UUID { entry.id }

        public func isReady(at now: Date) -> Bool {
            result == nil && (checkAt.map { now >= $0 } ?? true)
        }
    }

    /// The plan's patch-test item, if it mentions one.
    public let planItem: PlanItemInfo?
    /// How long the plan says to wait.
    public let wait: TimeInterval?
    public let running: [Test]
    /// Checked in the last week, newest first.
    public let recent: [Test]

    public var isEmpty: Bool { planItem == nil && running.isEmpty && recent.isEmpty }

    public init(items: [PlanItemInfo], logs: [LogEntry], now: Date) {
        let item = items.first { $0.text.localizedCaseInsensitiveContains("patch") }
        planItem = item
        let waited = Self.wait(item?.duration ?? item?.text)
        wait = waited
        let tests = logs.filter { $0.type == .patchTest }.sorted { $0.timestamp > $1.timestamp }.map { entry -> Test in
            let result: PatchResult? = if case .patch(let r)? = entry.value { r } else { nil }
            return Test(entry: entry, label: entry.note ?? "Patch test",
                        checkAt: waited.map { entry.timestamp.addingTimeInterval($0) }, result: result)
        }
        running = tests.filter { $0.result == nil }
        recent = tests.filter { $0.result != nil && now.timeIntervalSince($0.entry.timestamp) < 7 * 86_400 }
    }

    /// "24 hours", "48 hrs", "2 days", "24h" → seconds. Nil when no amount of time is written.
    public static func wait(_ text: String?) -> TimeInterval? {
        guard let text = text?.lowercased() else { return nil }
        let pattern = /(\d+)\s*(hours?|hrs?|h\b|days?)/
        guard let match = text.firstMatch(of: pattern), let amount = Double(match.1) else { return nil }
        return match.2.hasPrefix("d") ? amount * 86_400 : amount * 3_600
    }
}
