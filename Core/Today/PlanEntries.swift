import Foundation
import SwiftData

/// Plan tab (v3): the running plan as a read-first list. Each plan item is
/// one entry in a section, with a one-line meta; the detail page reads its
/// status, times, and the provider's full words from here. Nothing here
/// changes data; `PlanEntryActions` does, from the detail page.
public struct PlanEntries: Equatable, Sendable {
    public enum Section: String, CaseIterable, Sendable {
        case skin, supplements, baths, food, home, notes

        public var title: String {
            switch self {
            case .skin: "Skin care"
            case .supplements: "Supplements"
            case .baths: "Baths"
            case .food: "Food"
            case .home: "Home"
            case .notes: "Plan notes"
            }
        }
    }

    public struct Entry: Identifiable, Equatable, Sendable {
        public enum Status: Equatable, Sendable {
            /// In the daily list (To do), since this date when it's known.
            case active(since: Date?)
            case notStarted
            /// Off the daily list, since this date when it's known.
            case stopped(on: Date?)
            /// For reading: it never goes in the daily list.
            case reference
        }

        /// What the detail page's button changes.
        public enum Kind: Equatable, Sendable {
            /// Given at the times in `times` (`PlanItem.isGiving`, `givingTimes`).
            case supplement
            /// Done at the times in `times` (one routine step per time).
            case steps
            /// No button, no times.
            case reading
        }

        public struct Time: Equatable, Sendable, Identifiable {
            public let block: TodoBlock
            public let isOn: Bool
            public var id: TodoBlock { block }
        }

        public let item: PlanItemInfo
        public let section: Section
        public let kind: Kind
        /// Verb-first for tasks: "Apply aloe vera", "Give ION Gut Support".
        public let label: String
        /// One line under the label.
        public let meta: String?
        public let status: Status
        /// The blocks a task can be done in, on or off. Empty for reading.
        public let times: [Time]
        /// "1 teaspoon (5ml)", for "How much and when".
        public let amount: String?
        /// The provider's words, whole.
        public let words: String
        /// The item's routine steps, by time (steps only).
        public let stepIDs: [RoutineTime: UUID]

        public var id: UUID { item.id }
        public var isActive: Bool { if case .active = status { true } else { false } }
    }

    public let sections: [(section: Section, entries: [Entry])]

    public static func == (lhs: PlanEntries, rhs: PlanEntries) -> Bool {
        lhs.sections.map(\.section) == rhs.sections.map(\.section)
            && lhs.sections.map(\.entries) == rhs.sections.map(\.entries)
    }

    public var all: [Entry] { sections.flatMap(\.entries) }

    public func entry(_ id: UUID) -> Entry? { all.first { $0.id == id } }

    /// - Parameters:
    ///   - items: the running plan's items.
    ///   - steps: the child's routine steps, paused ones included.
    ///   - logs: the child's supplement logs (for "since" and "Stopped" dates).
    public init(items: [PlanItemInfo], steps: [RoutineStepInfo], logs: [LogEntry], now: Date = .now,
                calendar: Calendar = .autoupdatingCurrent) {
        let parents = Set(items.compactMap(\.parentItemID))
        let ordered = items.filter { !parents.contains($0.id) }.sorted { $0.order < $1.order }
        // The plan's skin frequency ("3-4x per day") lives in a note line; every skin step shares it.
        let skinPhrase = ordered.lazy.compactMap { StepLabeler.frequencyPhrase(in: $0.sourceParagraph ?? $0.sourceLine ?? $0.text) }.first
        var bySection: [Section: [Entry]] = [:]
        var skinNumber = 0

        for item in ordered {
            let words = item.providerWords
            switch item.kind {
            case .routineStep, .topicalStep:
                let mine = steps.filter { $0.planItemID == item.id }
                let tasks = mine.filter { $0.kind == .task }
                guard let first = tasks.first else {
                    bySection[.notes, default: []].append(Self.reading(item, section: .notes))
                    continue
                }
                skinNumber += 1
                let active = tasks.filter(\.isActive)
                let status: Entry.Status = active.isEmpty
                    ? .stopped(on: tasks.compactMap(\.updatedAt).max())
                    : .active(since: active.compactMap(\.createdAt).min())
                let number = Self.stepNumber(in: item.sourceLine ?? item.text) ?? skinNumber
                let often = PlanWords.timesADay(item.frequency) ?? PlanWords.timesADay(skinPhrase)
                let byTime = Dictionary(tasks.map { ($0.time, $0) }, uniquingKeysWith: { a, _ in a })
                let planned = Set(PlanRoutine.times(text: item.text, timing: item.timing, frequency: item.frequency))
                let times: [Entry.Time] = [RoutineTime.morning, .evening].map { time in
                    let isOn = byTime[time].map(\.isActive) ?? false
                    // Not in the list yet: show the plan's times, ready for "Add to daily list".
                    let shown = active.isEmpty ? (byTime[time] != nil || planned.contains(time)) : isOn
                    return Entry.Time(block: time == .morning ? .morning : .bedtime, isOn: shown)
                }
                bySection[.skin, default: []].append(Entry(
                    item: item, section: .skin, kind: .steps, label: first.displayName,
                    meta: Self.meta(status, calendar: calendar,
                                    active: (["Step \(number)", often].compactMap { $0 }).joined(separator: " · ")),
                    status: status, times: times, amount: item.dose, words: words,
                    stepIDs: byTime.mapValues(\.id)
                ))
            case .supplement where SupplementPlan.isProduct(item):
                let display = SupplementDisplay(item)
                let mine = logs.filter { $0.type == .supplement && $0.routineStepID == item.id }
                func last(_ event: SupplementEvent) -> Date? {
                    mine.filter { $0.value == .supplement(event) }.map(\.timestamp).max()
                }
                // Given now; or given before and stopped (it has a start log); or never started.
                let status: Entry.Status = item.isGiving == true ? .active(since: last(.started))
                    : last(.started) != nil ? .stopped(on: last(.stopped)) : .notStarted
                let blocks = item.blocks
                let when = PlanWords.blocks(blocks)
                bySection[.supplements, default: []].append(Entry(
                    item: item, section: .supplements, kind: .supplement, label: "Give \(display.name)",
                    meta: Self.meta(status, calendar: calendar,
                                    active: [item.dose(on: now, calendar: calendar), when].compactMap { $0 }.joined(separator: " · ")),
                    status: status,
                    times: TodoBlock.allCases.map { Entry.Time(block: $0, isOn: blocks.contains($0)) },
                    amount: item.dose(on: now, calendar: calendar), words: words, stepIDs: [:]
                ))
            case .bath:
                bySection[.baths, default: []].append(Self.reading(item, section: .baths))
            case .foodRule:
                bySection[.food, default: []].append(Self.reading(item, section: .food))
            case .fundamental:
                bySection[.home, default: []].append(Self.reading(item, section: .home))
            default:
                bySection[.notes, default: []].append(Self.reading(item, section: .notes))
            }
        }
        sections = Section.allCases.compactMap { section in
            guard let entries = bySection[section], !entries.isEmpty else { return nil }
            return (section, entries)
        }
    }

    /// A line to read: no button, no times. Meta is how often and how long, when the plan says.
    private static func reading(_ item: PlanItemInfo, section: Section) -> Entry {
        let meta = [PlanWords.timesADay(item.frequency) ?? item.frequency, item.duration].compactMap { $0 }.joined(separator: " · ")
        return Entry(item: item, section: section, kind: .reading,
                     label: item.plainText ?? StepLabeler.clean(item.text),
                     meta: meta.isEmpty ? nil : meta, status: .reference, times: [], amount: nil,
                     words: item.providerWords, stepIDs: [:])
    }

    /// The list's meta line for a task: its own words when active, else the status.
    private static func meta(_ status: Entry.Status, calendar: Calendar, active: String) -> String? {
        switch status {
        case .active: active.isEmpty ? nil : active
        case .notStarted: "Not started yet"
        case .stopped(let date): date.map { "Stopped \(PlanWords.day($0, calendar: calendar))" } ?? "Stopped"
        case .reference: nil
        }
    }

    /// "Step 2: Aloe vera…" → 2.
    static func stepNumber(in text: String) -> Int? {
        guard let match = text.firstMatch(of: /(?i)^\s*step\s*(\d+)/) else { return nil }
        return Int(match.1)
    }
}

/// Plain words for the Plan tab.
public enum PlanWords {
    /// "3-4x per day" → "3 to 4 times a day", "2x daily" → "2 times a day",
    /// "once daily" → "once a day", "3x/week" → "3 times a week". Nil when it doesn't say.
    public static func timesADay(_ text: String?) -> String? {
        guard let text = text?.lowercased() else { return nil }
        let unit = text.contains("week") ? "week" : (text.contains("day") || text.contains("daily")) ? "day" : nil
        guard let unit else { return nil }
        if let range = text.firstMatch(of: /(\d+)\s*[-–]\s*(\d+)\s*(?:x|times)/) {
            return "\(range.1) to \(range.2) times a \(unit)"
        }
        if text.contains("once") { return "once a \(unit)" }
        if text.contains("twice") { return "twice a \(unit)" }
        if let count = text.firstMatch(of: /(\d+)\s*(?:x|times)/) {
            return count.1 == "1" ? "once a \(unit)" : "\(count.1) times a \(unit)"
        }
        return nil
    }

    /// [.morning, .bedtime] → "Morning and bedtime"; all three → "Morning, afternoon, and bedtime".
    public static func blocks(_ blocks: [TodoBlock]) -> String? {
        let names = TodoBlock.allCases.filter(blocks.contains).map(\.title)
        guard let first = names.first else { return nil }
        let rest = names.dropFirst().map { $0.lowercased() }
        switch rest.count {
        case 0: return first
        case 1: return "\(first) and \(rest[0])"
        default: return "\(first), " + rest.dropLast().joined(separator: ", ") + ", and \(rest.last!)"
        }
    }

    /// "Sep 12"
    public static func day(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// "In your daily list since Sep 12" / "Not started yet" / "Stopped Sep 30".
    public static func status(_ status: PlanEntries.Entry.Status, calendar: Calendar = .autoupdatingCurrent) -> String? {
        switch status {
        case .active(let since): since.map { "In your daily list since \(day($0, calendar: calendar))" } ?? "In your daily list"
        case .notStarted: "Not started yet"
        case .stopped(let on): on.map { "Stopped \(day($0, calendar: calendar))" } ?? "Stopped"
        case .reference: nil
        }
    }
}

/// Starts and stops a plan entry from its detail page, through the stores
/// To do already reads. Stopping only turns things off; every log stays.
public struct PlanEntryActions: Sendable {
    private let routine: RoutineStore
    private let plans: CarePlanStore
    private let logs: LogStore
    private let child: UUID

    public init(container: ModelContainer, child: UUID, now: @escaping @Sendable () -> Date = { .now }) {
        routine = RoutineStore(modelContainer: container, now: now)
        plans = CarePlanStore(modelContainer: container, now: now)
        logs = LogStore(modelContainer: container, now: now)
        self.child = child
    }

    /// Puts it in the daily list at these blocks.
    public func start(_ entry: PlanEntries.Entry, at blocks: [TodoBlock]) async throws {
        switch entry.kind {
        case .supplement:
            try await plans.setGivingTimes(entry.item.id, blocks)
            try await plans.setGiving(entry.item.id, true)
            _ = try await logs.logSupplement(.started, item: entry.item.id, child: child, source: .app)
        case .steps:
            for time in RoutineTime.allCases {
                try await setStep(entry, time, on: blocks.contains(Self.block(time)))
            }
        case .reading:
            break
        }
    }

    /// Takes it off the daily list. History stays.
    public func stop(_ entry: PlanEntries.Entry) async throws {
        switch entry.kind {
        case .supplement:
            try await plans.setGiving(entry.item.id, false)
            _ = try await logs.logSupplement(.stopped, item: entry.item.id, child: child, source: .app)
        case .steps:
            for id in entry.stepIDs.values { try await routine.setActive(id, false) }
        case .reading:
            break
        }
    }

    /// One block on or off while it's in the daily list.
    public func set(_ entry: PlanEntries.Entry, _ block: TodoBlock, on: Bool) async throws {
        switch entry.kind {
        case .supplement:
            var blocks = Set(entry.times.filter(\.isOn).map(\.block))
            if on { blocks.insert(block) } else { blocks.remove(block) }
            try await plans.setGivingTimes(entry.item.id, TodoBlock.allCases.filter(blocks.contains))
        case .steps:
            guard let time = block.routineTime else { return }
            try await setStep(entry, time, on: on)
        case .reading:
            break
        }
    }

    /// A dose step the parent set: this amount from this day on.
    public func addDoseStep(_ entry: PlanEntries.Entry, amount: String, from date: Date) async throws {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var steps = entry.item.doseSteps.filter { $0.startDate != date }
        steps.append(DoseStep(amount: String(trimmed.prefix(80)), startDate: date))
        try await plans.setDoseSteps(entry.item.id, steps)
    }

    public func removeDoseStep(_ entry: PlanEntries.Entry, _ step: DoseStep) async throws {
        try await plans.setDoseSteps(entry.item.id, entry.item.doseSteps.filter { $0 != step })
    }

    private func setStep(_ entry: PlanEntries.Entry, _ time: RoutineTime, on: Bool) async throws {
        if let id = entry.stepIDs[time] {
            try await routine.setActive(id, on)
        } else if on {
            try await plans.addSteps(for: entry.item.id, times: [time])
        }
    }

    private static func block(_ time: RoutineTime) -> TodoBlock { time == .morning ? .morning : .bedtime }
}
