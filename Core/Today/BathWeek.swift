import Foundation

/// Plan's Baths section: each bath the plan lists, how many times a week it
/// says, and how many were logged this week. It never picks a bath for you.
public struct BathWeek: Equatable, Sendable {
    public struct Row: Equatable, Sendable, Identifiable {
        public let item: PlanItemInfo
        /// From the plan's words ("3x/week" → 3). Nil when it doesn't say.
        public let perWeek: Int?
        public let doneThisWeek: Int
        public let lastDone: Date?
        public var id: UUID { item.id }
    }

    public let rows: [Row]
    /// The plan's bath rules in its own words, like "Baths (rotate, don't combine)".
    public let notes: [String]

    /// `logs` are the child's bath logs (any order). The week starts on the
    /// calendar's first weekday, at the start of that day.
    public init(items: [PlanItemInfo], logs: [LogEntry], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let baths = items.filter { $0.kind == .bath }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let bathLogs = logs.filter { $0.type == .bath }
        rows = baths.filter { $0.frequency != nil || $0.duration != nil }.map { item in
            let mine = bathLogs.filter { $0.routineStepID == item.id }
            return Row(
                item: item,
                perWeek: Self.perWeek(item.frequency),
                doneThisWeek: mine.filter { $0.timestamp >= weekStart && $0.timestamp <= now }.count,
                lastDone: mine.map(\.timestamp).filter { $0 <= now }.max()
            )
        }
        notes = baths.filter { $0.frequency == nil && $0.duration == nil }.map(\.text)
    }

    /// "3x/week", "3 times a week", "twice weekly", "once a week" → a number.
    public static func perWeek(_ frequency: String?) -> Int? {
        guard let text = frequency?.lowercased(), text.contains("week") else { return nil }
        if text.contains("once") { return 1 }
        if text.contains("twice") { return 2 }
        return text.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
    }
}
