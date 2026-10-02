import Foundation

/// Plan's Provider section: the next visit, when the plan says to follow up,
/// and how many messages are left of the plan's allowance. Only what the plan
/// and the parent's own records say.
public struct ProviderTracker: Equatable, Sendable {
    public struct Allowance: Equatable, Sendable {
        public let total: Int
        public let used: Int
        public let until: Date?
        public var left: Int { max(total - used, 0) }

        public init(total: Int, used: Int, until: Date?) {
            self.total = total
            self.used = used
            self.until = until
        }
    }

    public let nextVisit: VisitInfo?
    public let lastVisit: VisitInfo?
    /// "Follow-up visit in 4–6 weeks" from the plan's start: the earliest and latest dates.
    public let followUp: (from: Date, to: Date)?
    public let messages: Allowance?

    public static func == (a: Self, b: Self) -> Bool {
        a.nextVisit == b.nextVisit && a.lastVisit == b.lastVisit && a.messages == b.messages
            && a.followUp?.from == b.followUp?.from && a.followUp?.to == b.followUp?.to
    }

    public init(plan: CarePlanInfo?, items: [PlanItemInfo], visits: [VisitInfo], logs: [LogEntry], now: Date,
                calendar: Calendar = .autoupdatingCurrent) {
        nextVisit = visits.filter { $0.date > now }.min { $0.date < $1.date }
        lastVisit = visits.filter { $0.date <= now }.max { $0.date < $1.date }
        let start = plan?.startedAt
        let lines = items.map { ([$0.text, $0.duration, $0.sourceLine].compactMap { $0 }).joined(separator: " ").lowercased() }

        if let start, let weeks = lines.lazy.compactMap(Self.followUpWeeks).first {
            followUp = (calendar.date(byAdding: .day, value: weeks.0 * 7, to: start) ?? start,
                        calendar.date(byAdding: .day, value: weeks.1 * 7, to: start) ?? start)
        } else {
            followUp = nil
        }

        if let rule = lines.lazy.compactMap(Self.messageAllowance).first {
            let used = logs.filter { log in
                log.type == .providerMessage && log.timestamp <= now && (start.map { log.timestamp >= $0 } ?? true)
            }.count
            messages = Allowance(total: rule.count, used: used,
                                 until: start.flatMap { calendar.date(byAdding: .day, value: rule.weeks * 7, to: $0) })
        } else {
            messages = nil
        }
    }

    /// "follow-up visit in 4–6 weeks" → (4, 6); "follow up in 6 weeks" → (6, 6).
    public static func followUpWeeks(_ text: String) -> (Int, Int)? {
        guard text.contains("follow"), text.contains("visit") || text.contains("appointment") || text.contains("follow-up in")
        else { return nil }
        guard let match = text.firstMatch(of: /in\s+(\d+)\s*(?:[–-]\s*(\d+)\s*)?weeks?/), let low = Int(match.1) else { return nil }
        return (low, match.2.flatMap { Int($0) } ?? low)
    }

    /// "up to 5 follow-up messages within 8 weeks" → (5, 8).
    public static func messageAllowance(_ text: String) -> (count: Int, weeks: Int)? {
        guard let match = text.firstMatch(of: /(\d+)\s+(?:follow-up\s+)?messages?\s+(?:within|in|over)\s+(\d+)\s*weeks?/),
              let count = Int(match.1), let weeks = Int(match.2)
        else { return nil }
        return (count, weeks)
    }
}
