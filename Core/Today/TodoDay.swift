import Foundation

/// To do: "What do I do right now?" One day's blocks (Morning, Afternoon,
/// Bedtime), what's in each, what's done, the skin-care counter, and which
/// block is open. Pure: built from steps, plan items, today's logs, and times.
public struct TodoDay: Equatable, Sendable {
    /// One thing to do in a block.
    public struct Item: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable {
            case step(RoutineStepInfo)
            case supplement(PlanItemInfo)
            /// Skin care: the plan's skin steps as one row, counted per day.
            case skin
        }

        public let kind: Kind
        public let label: String
        /// At most one short line: a dose, or "2 of 3-4 today".
        public let meta: String?
        public let isDone: Bool
        /// The latest log that ticked it, for "Done 7:50" and for undoing.
        public let lastLog: LogEntry?
        public var doneAt: Date? { lastLog?.timestamp }

        public var id: String {
            switch kind {
            case .step(let step): step.id.uuidString
            case .supplement(let item): item.id.uuidString
            case .skin: "skin"
            }
        }
    }

    public struct Block: Equatable, Sendable, Identifiable {
        public let block: TodoBlock
        public let startsAt: Date
        public let items: [Item]
        public var id: TodoBlock { block }
        public var doneCount: Int { items.filter(\.isDone).count }
        public var isDone: Bool { !items.isEmpty && doneCount == items.count }
        /// "3 of 5 done".
        public var progress: String { "\(doneCount) of \(items.count) done" }
    }

    /// The skin-care counter: rounds today against the plan's count ("3-4x per day").
    public struct Skin: Equatable, Sendable {
        public let steps: [RoutineStepInfo]
        public let rounds: Int
        /// The plan's count, low and high ("3-4" → 3...4); nil when it gives none.
        public let target: ClosedRange<Int>?
        public var isDone: Bool { target.map { rounds >= $0.lowerBound } ?? (rounds > 0) }
        /// "2 of 3-4 today", or "Done today" when the plan gives no count.
        public var meta: String {
            guard let target else { return rounds > 0 ? "Done today" : "Once today" }
            let goal = target.lowerBound == target.upperBound ? "\(target.lowerBound)" : "\(target.lowerBound)-\(target.upperBound)"
            return "\(rounds) of \(goal) today"
        }
    }

    public let blocks: [Block]
    public let skin: Skin?
    /// The block to show open; nil when everything is done for the day.
    public let open: TodoBlock?
    /// When the morning list starts tomorrow, for "Morning list starts at 7:30 AM."
    public let nextMorning: Date

    public var allDone: Bool { open == nil }

    /// - Parameters:
    ///   - steps: the child's routine steps (all of them; inactive and notes are left out here).
    ///   - items: the active plan's items.
    ///   - logs: the child's logs for today (calendar day).
    ///   - times: each block's start, hour and minute.
    public init(steps: [RoutineStepInfo], items: [PlanItemInfo], logs: [LogEntry], times: [TodoBlock: DateComponents],
                now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let start = calendar.startOfDay(for: now)
        let today = logs.filter { $0.timestamp >= start && $0.timestamp <= now }
        func at(_ block: TodoBlock, dayOffset: Int = 0) -> Date {
            let parts = times[block] ?? Self.defaultTimes[block]!
            let day = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
        }

        let tasks = steps.filter { $0.isActive && $0.kind == .task }.sorted { $0.order < $1.order }
        // The plan's skin steps (Apply steps from a plan) become one counted row.
        let skinSteps = tasks.filter { $0.category == .apply && $0.planItemID != nil }
        let skinIDs = Set(skinSteps.map(\.id))
        let notes = steps.filter { $0.isActive && $0.kind == .note }
        let skin: Skin? = skinSteps.isEmpty ? nil : {
            // A round is one log on any skin step (morning or evening copy of the same plan item).
            let byItem = Dictionary(grouping: today.filter { $0.type == .routineDone && $0.routineStepID.map(skinIDs.contains) == true }) {
                log in skinSteps.first { $0.id == log.routineStepID }?.planItemID
            }
            let rounds = byItem.values.map(\.count).max() ?? 0
            let phrase = notes.lazy.compactMap { StepLabeler.frequencyPhrase(in: $0.original) }.first
            return Skin(steps: Self.oneOfEach(skinSteps), rounds: rounds, target: Self.range(phrase))
        }()

        // A list split into its own items ("Continue A, B") shows as those items; mentions never show.
        let parents = Set(items.compactMap(\.parentItemID))
        let giving = items.filter {
            $0.kind == .supplement && $0.isGiving == true && !parents.contains($0.id) && !SupplementDisplay.isMention($0.text)
        }.sorted { $0.order < $1.order }
        let taken = today.filter { $0.type == .supplement && $0.value == .supplement(.taken) }

        var blocks: [Block] = []
        for block in TodoBlock.allCases {
            var list: [Item] = []
            if let time = block.routineTime {
                for step in tasks where step.time == time && !skinIDs.contains(step.id) {
                    let done = today.filter { $0.type == .routineDone && $0.routineStepID == step.id }
                    list.append(Item(kind: .step(step), label: step.displayName, meta: nil,
                                     isDone: !done.isEmpty, lastLog: done.max { $0.timestamp < $1.timestamp }))
                }
            }
            for item in giving where item.blocks.contains(block) {
                let doses = Self.doses(for: item, in: block, taken: taken)
                list.append(Item(kind: .supplement(item), label: "Give \(SupplementDisplay(item).name)",
                                 meta: item.dose(on: now, calendar: calendar), isDone: !doses.isEmpty, lastLog: doses.max { $0.timestamp < $1.timestamp }))
            }
            // Afternoon shows only when it has something in it.
            if block == .afternoon && list.isEmpty { continue }
            blocks.append(Block(block: block, startsAt: at(block), items: list))
        }

        // Skin care sits in whichever block is open; it counts once for the day.
        let openBlock = Self.openBlock(blocks, now: now)
        if let skin, let openBlock, let index = blocks.firstIndex(where: { $0.block == openBlock }) {
            let row = Item(kind: .skin, label: "Do skin care", meta: skin.meta, isDone: skin.isDone, lastLog: nil)
            let old = blocks[index]
            blocks[index] = Block(block: old.block, startsAt: old.startsAt, items: Self.insertSkin(row, into: old.items))
        }
        self.blocks = blocks
        self.skin = skin
        self.open = Self.openBlock(blocks, now: now)
        self.nextMorning = at(.morning, dayOffset: 1)
    }

    public static let defaultTimes: [TodoBlock: DateComponents] = [
        .morning: DateComponents(hour: 7, minute: 30),
        .afternoon: DateComponents(hour: 12, minute: 30),
        .bedtime: DateComponents(hour: 19, minute: 0),
    ]

    /// A block opens an hour before its time.
    static let lead: TimeInterval = 3600

    /// Before the first block: Morning. Otherwise the latest block that has
    /// started; if it's all done, the next one that isn't. Nil once the last
    /// block is done.
    static func openBlock(_ blocks: [Block], now: Date) -> TodoBlock? {
        guard let first = blocks.first else { return nil }
        let started = blocks.lastIndex { $0.startsAt.addingTimeInterval(-lead) <= now } ?? 0
        if blocks.last?.isDone == true && started == blocks.count - 1 { return nil }
        if let next = blocks[started...].first(where: { !$0.isDone }) { return next.block }
        return blocks.last?.isDone == true ? nil : first.block
    }

    /// A step's doses in a block: logs noted with the block, plus older logs
    /// without one, given to the earliest blocks first.
    static func doses(for item: PlanItemInfo, in block: TodoBlock, taken: [LogEntry]) -> [LogEntry] {
        let mine = taken.filter { $0.routineStepID == item.id }
        let noted = mine.filter { $0.note == block.rawValue }
        if !noted.isEmpty { return noted }
        let unnoted = mine.filter { $0.note.flatMap(TodoBlock.init) == nil }.sorted { $0.timestamp < $1.timestamp }
        let blocks = item.blocks
        let free = blocks.filter { b in !mine.contains { $0.note == b.rawValue } }
        guard let index = free.firstIndex(of: block), index < unnoted.count else { return [] }
        return [unnoted[index]]
    }

    /// Skin care goes after the steps, before the supplements.
    static func insertSkin(_ row: Item, into items: [Item]) -> [Item] {
        let firstSupplement = items.firstIndex { if case .supplement = $0.kind { true } else { false } } ?? items.count
        var list = items
        list.insert(row, at: firstSupplement)
        return list
    }

    /// Each plan skin step once (they exist for morning and evening), in order.
    static func oneOfEach(_ steps: [RoutineStepInfo]) -> [RoutineStepInfo] {
        var seen = Set<UUID>()
        return steps.sorted { ($0.time == .morning ? 0 : 1, $0.order) < ($1.time == .morning ? 0 : 1, $1.order) }
            .filter { seen.insert($0.planItemID ?? $0.id).inserted }
    }

    /// "3-4x per day" → 3...4; "2x daily" → 2...2.
    static func range(_ phrase: String?) -> ClosedRange<Int>? {
        guard let phrase, let match = phrase.firstMatch(of: /(\d+)(?:\s*[-–]\s*(\d+))?/), let low = Int(match.1) else { return nil }
        let high = match.2.flatMap { Int($0) } ?? low
        return low...max(low, high)
    }
}
