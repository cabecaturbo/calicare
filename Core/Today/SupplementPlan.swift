import Foundation

/// Plan's Supplements: only the supplements the plan lists, with the plan's own
/// rules ("one at a time, 3–5 days apart", "start probiotic 2 weeks after
/// antimicrobial", "rotate after 3 weeks"). It proposes "can start after"
/// dates from those rules; the parent decides. Missing rules stay missing.
public struct SupplementPlan: Equatable, Sendable {
    public struct Row: Equatable, Sendable, Identifiable {
        public let item: PlanItemInfo
        public let started: Date?
        public let stopped: Date?
        /// Taken today (since the start of the calendar day).
        public let takenToday: Int
        /// From the plan's words: "twice daily" → 2. Nil when it doesn't say.
        public let perDay: Int?
        /// The earliest start the plan's rules allow, when a rule applies and it hasn't started.
        public let canStartAfter: Date?
        /// "Starts 2 weeks after Antimicrobial herb starts", when that one hasn't started yet.
        public let waitingFor: String?
        /// "Rotate after 3 weeks" from the plan, as a date once started.
        public let rotateOn: Date?
        public var id: UUID { item.id }

        public var isActive: Bool { started != nil && stopped == nil }
    }

    public let rows: [Row]
    /// The plan's supplement rules in its own words.
    public let rules: [String]
    /// "Consider adding…" and "…may be indicated" lines: shown muted, with no actions.
    public let mentioned: [PlanItemInfo]

    /// "Consider adding…" with no dose or schedule: a mention, not something to give.
    public static func isMention(_ item: PlanItemInfo) -> Bool {
        item.dose == nil && item.frequency == nil && SupplementDisplay.isMention(item.text)
    }

    /// Something to give: a dose or schedule, a split item, or an "ADD X" or
    /// "Transition to X" line. Other supplement lines are the plan's rules
    /// ("one at a time, 3–5 days apart").
    public static func isProduct(_ item: PlanItemInfo) -> Bool {
        !isMention(item)
            && (item.dose != nil || item.frequency != nil || item.parentItemID != nil || SupplementDisplay.isDirective(item.text))
    }

    public init(items: [PlanItemInfo], logs: [LogEntry], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let all = items.filter { $0.kind == .supplement }.sorted { $0.order < $1.order }
        // A list split into its own items ("Continue A, B") shows as those items.
        let parents = Set(all.compactMap(\.parentItemID))
        let supplements = all.filter { !parents.contains($0.id) }
        mentioned = supplements.filter(Self.isMention)
        let mentionIDs = Set(mentioned.map(\.id))
        let products = supplements.filter(Self.isProduct)
        let productIDs = Set(products.map(\.id))
        let ruleItems = supplements.filter { !productIDs.contains($0.id) && !mentionIDs.contains($0.id) }
        rules = ruleItems.map(\.text)
        let ruleText = (ruleItems.map(\.text) + supplements.compactMap(\.sourceLine)).joined(separator: "\n").lowercased()

        let mine = logs.filter { $0.type == .supplement }
        func last(_ event: SupplementEvent, _ id: UUID) -> Date? {
            mine.filter { $0.routineStepID == id && $0.value == .supplement(event) && $0.timestamp <= now }.map(\.timestamp).max()
        }
        let startOfToday = calendar.startOfDay(for: now)
        let starts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, last(.started, $0.id)) })
        let spacing = Self.daysApart(ruleText)
        let latestStart = starts.values.compactMap { $0 }.max()

        rows = products.map { item in
            let started = starts[item.id] ?? nil
            let stoppedAt = last(.stopped, item.id)
            let stopped = stoppedAt.flatMap { stop in started.map { stop > $0 } ?? true ? stop : nil }
            var canStartAfter: Date?
            var waitingFor: String?
            if started == nil {
                if let spacing, let latestStart {
                    canStartAfter = calendar.date(byAdding: .day, value: spacing, to: latestStart)
                }
                if let after = Self.startsAfter(item, in: ruleText, among: products) {
                    if let otherStart = starts[after.other.id] ?? nil {
                        let date = calendar.date(byAdding: .day, value: after.days, to: otherStart)
                        canStartAfter = [canStartAfter, date].compactMap { $0 }.max()
                    } else {
                        waitingFor = "Starts \(after.words) after \(after.other.text) starts"
                    }
                }
            }
            let rotateWeeks = Self.rotateWeeks(item)
            return Row(
                item: item,
                started: started,
                stopped: stopped,
                takenToday: mine.filter {
                    $0.routineStepID == item.id && $0.value == .supplement(.taken) && $0.timestamp >= startOfToday && $0.timestamp <= now
                }.count,
                perDay: Self.perDay(item.frequency),
                canStartAfter: canStartAfter,
                waitingFor: waitingFor,
                rotateOn: started.flatMap { start in rotateWeeks.flatMap { calendar.date(byAdding: .day, value: $0 * 7, to: start) } }
            )
        }
    }

    /// "3–5 days apart" → 3 (the plan's shortest gap).
    public static func daysApart(_ text: String) -> Int? {
        guard let match = text.firstMatch(of: /(\d+)\s*(?:[–-]\s*\d+\s*)?days?\s+apart/) else { return nil }
        return Int(match.1)
    }

    /// "once daily" → 1, "twice daily" → 2, "3x/day" → 3.
    public static func perDay(_ frequency: String?) -> Int? {
        guard let text = frequency?.lowercased(), text.contains("day") || text.contains("daily") else { return nil }
        if text.contains("once") { return 1 }
        if text.contains("twice") { return 2 }
        if text.contains("three times") { return 3 }
        if let match = text.firstMatch(of: /(\d+)\s*(?:x|times)/) { return Int(match.1) }
        return text.contains("daily") ? 1 : nil
    }

    /// "rotate after 3 weeks" on the item's own line → 3.
    static func rotateWeeks(_ item: PlanItemInfo) -> Int? {
        let text = ([item.text, item.duration, item.sourceLine].compactMap { $0 }).joined(separator: " ").lowercased()
        guard let match = text.firstMatch(of: /rotate after (\d+)\s*weeks?/) else { return nil }
        return Int(match.1)
    }

    /// "start probiotic 2 weeks after antimicrobial": the other supplement and the gap in days.
    static func startsAfter(_ item: PlanItemInfo, in text: String, among products: [PlanItemInfo])
        -> (other: PlanItemInfo, days: Int, words: String)? {
        for match in text.matches(of: /start\s+(?:the\s+)?([a-z][a-z0-9 -]*?)\s+(\d+)\s*(days?|weeks?)\s+after\s+(?:the\s+)?([a-z][a-z0-9 -]*)/) {
            let (target, amount, unit, otherName) = (String(match.1), Int(match.2) ?? 0, String(match.3), String(match.4))
            guard Self.names(item, target),
                  let other = products.first(where: { $0.id != item.id && Self.names($0, otherName) })
            else { continue }
            let days = unit.hasPrefix("week") ? amount * 7 : amount
            return (other, days, "\(amount) \(unit)")
        }
        return nil
    }

    /// Whether a few words from a rule name this item ("probiotic" → "Probiotic, Brand A").
    static func names(_ item: PlanItemInfo, _ words: String) -> Bool {
        let first = words.split(separator: " ").first.map(String.init) ?? words
        return item.text.lowercased().contains(first)
    }
}
