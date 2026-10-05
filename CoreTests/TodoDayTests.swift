import Core
import Foundation
import SwiftData
import Testing

/// To do: blocks, which one is open, the skin counter, and supplement times.
struct TodoDayTests {
    private let child = UUID()
    private let calendar = TestTime.calendar

    private func step(_ name: String, _ time: RoutineTime, _ order: Int, category: StepCategory? = nil,
                      plan: UUID? = nil, kind: StepKind = .task, source: String? = nil) -> RoutineStepInfo {
        RoutineStepInfo(id: UUID(), childID: child, name: name, time: time, order: order, isActive: true, planItemID: plan,
                        label: StepLabeler.wording(for: name).label, sourceText: source ?? name, category: category, kind: kind)
    }

    private func supplement(_ text: String, dose: String? = nil, frequency: String? = nil, giving: Bool? = true,
                            times: [TodoBlock]? = nil) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: .supplement, text: text, dose: dose, frequency: frequency, timing: nil,
                     duration: nil, sourcePage: 1, sourceLine: text, isConfirmed: true, order: 0, isGiving: giving, givingTimes: times)
    }

    private func log(_ type: LogType, _ value: LogValue?, step: UUID?, at date: Date, note: String? = nil) -> LogEntry {
        LogEntry(childID: child, type: type, value: value, note: note, timestamp: date, routineStepID: step)
    }

    private var sample: (steps: [RoutineStepInfo], items: [PlanItemInfo]) {
        let skinItem = UUID()
        let steps = [
            step("Wash face", .morning, 0), step("Moisturizer", .morning, 1),
            step("Bath", .evening, 0), step("Pajamas", .evening, 1),
            step("Aloe vera", .morning, 2, category: .apply, plan: skinItem),
            step("Aloe vera", .evening, 2, category: .apply, plan: skinItem),
            step("Support the skin 3-4x per day", .evening, 3, category: .apply, kind: .note),
        ]
        let items = [
            supplement("ADD Drops", dose: "8 drops", frequency: "3x daily"),
            supplement("ADD Powder", dose: "1 tsp", frequency: "2x per day"),
            supplement("Vitamin C"),
            supplement("Not yet", dose: "1 tsp", frequency: "2x per day", giving: false),
        ]
        return (steps, items)
    }

    @Test func blocksHoldTheRightThings() {
        let (steps, items) = sample
        let day = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: TestTime.date(26, 8), calendar: calendar)
        #expect(day.blocks.map(\.block) == [.morning, .afternoon, .bedtime])
        let morning = day.blocks[0].items.map(\.label)
        #expect(morning == ["Wash face", "Put on moisturizer", "Do skin care", "Give Drops", "Give Powder", "Give Vitamin C"])
        #expect(day.blocks[1].items.map(\.label) == ["Give Drops"])
        #expect(day.blocks[2].items.map(\.label) == ["Give a bath", "Put on pajamas", "Give Drops", "Give Powder"])
        #expect(day.open == .morning)
        #expect(day.blocks[0].items.first { $0.label == "Give Drops" }?.meta == "8 drops")
        #expect(day.skin?.meta == "0 of 3-4 today")
    }

    @Test func splitListsAndMentionsStayOff() {
        let list = supplement("Continue Vitamin D, Fish Oil")
        let child = PlanItemInfo(id: UUID(), planID: UUID(), kind: .supplement, text: "Vitamin D", dose: nil, frequency: nil, timing: nil,
                                 duration: nil, sourcePage: 1, sourceLine: list.text, isConfirmed: true, order: 0,
                                 parentItemID: list.id, isGiving: true)
        let mention = supplement("Consider adding Brand H")
        let day = TodoDay(steps: [], items: [list, child, mention], logs: [], times: TodoDay.defaultTimes,
                          now: TestTime.date(26, 8), calendar: calendar)
        #expect(day.blocks[0].items.map(\.label) == ["Give Vitamin D"])
    }

    @Test func afternoonHidesWhenEmpty() {
        let (steps, _) = sample
        let day = TodoDay(steps: steps, items: [supplement("Vitamin C")], logs: [], times: TodoDay.defaultTimes,
                          now: TestTime.date(26, 8), calendar: calendar)
        #expect(day.blocks.map(\.block) == [.morning, .bedtime])
    }

    @Test func theOpenBlockFollowsTheClockAndWhatsDone() {
        let (steps, items) = sample
        func open(at hour: Int, _ logs: [LogEntry] = []) -> TodoBlock? {
            TodoDay(steps: steps, items: items, logs: logs, times: TodoDay.defaultTimes, now: TestTime.date(26, hour), calendar: calendar).open
        }
        #expect(open(at: 3) == .morning)
        #expect(open(at: 12) == .afternoon)
        #expect(open(at: 20) == .bedtime)

        // Bedtime all done: nothing open, "All done for tonight".
        let at = TestTime.date(26, 20)
        let bed = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: at, calendar: calendar)
        var logs: [LogEntry] = []
        for item in bed.blocks.last!.items {
            switch item.kind {
            case .step(let s): logs.append(log(.routineDone, .routine(.evening), step: s.id, at: at))
            case .supplement(let p): logs.append(log(.supplement, .supplement(.taken), step: p.id, at: at, note: "bedtime"))
            case .skin: for s in bed.skin!.steps { for _ in 0..<3 { logs.append(log(.routineDone, .routine(.evening), step: s.id, at: at)) } }
            }
        }
        let done = TodoDay(steps: steps, items: items, logs: logs, times: TodoDay.defaultTimes, now: at.addingTimeInterval(60), calendar: calendar)
        #expect(done.allDone)
        #expect(done.nextMorning == TestTime.date(27, 7, 30))
    }

    @Test func aDoneMorningOpensTheNextBlockEarly() {
        let (steps, items) = sample
        let at = TestTime.date(26, 8)
        let first = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: at, calendar: calendar)
        var logs: [LogEntry] = []
        for item in first.blocks[0].items {
            switch item.kind {
            case .step(let s): logs.append(log(.routineDone, .routine(.morning), step: s.id, at: at))
            case .supplement(let p): logs.append(log(.supplement, .supplement(.taken), step: p.id, at: at, note: "morning"))
            case .skin: for s in first.skin!.steps { for _ in 0..<3 { logs.append(log(.routineDone, .routine(.morning), step: s.id, at: at)) } }
            }
        }
        let day = TodoDay(steps: steps, items: items, logs: logs, times: TodoDay.defaultTimes, now: at.addingTimeInterval(60), calendar: calendar)
        #expect(day.blocks[0].isDone)
        #expect(day.open == .afternoon)
    }

    @Test func skinCountsRoundsAgainstThePlan() {
        let (steps, items) = sample
        let skin = steps.filter { $0.category == .apply && $0.planItemID != nil }
        let at = TestTime.date(26, 9)
        let two = [log(.routineDone, .routine(.morning), step: skin[0].id, at: at), log(.routineDone, .routine(.evening), step: skin[1].id, at: at)]
        let day = TodoDay(steps: steps, items: items, logs: two, times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(day.skin?.rounds == 2)
        #expect(day.skin?.meta == "2 of 3-4 today")
        #expect(day.skin?.isDone == false)
        #expect(day.skin?.steps.count == 1)
    }

    @Test func supplementTimesFollowThePlan() {
        #expect(TodoBlock.defaults(forFrequency: nil) == [.morning])
        #expect(TodoBlock.defaults(forFrequency: "once daily") == [.morning])
        #expect(TodoBlock.defaults(forFrequency: "2x per day") == [.morning, .bedtime])
        #expect(TodoBlock.defaults(forFrequency: "3x daily") == [.morning, .afternoon, .bedtime])
        #expect(TodoBlock.parse("bedtime,morning") == [.morning, .bedtime])
        #expect(TodoBlock.raw([.bedtime, .morning, .morning]) == "morning,bedtime")
    }

    @Test func olderDosesWithoutABlockFillTheEarliestBlocks() {
        let drops = supplement("ADD Drops", dose: "8 drops", frequency: "3x daily")
        let at = TestTime.date(26, 13)
        let logs = [log(.supplement, .supplement(.taken), step: drops.id, at: at)]
        let day = TodoDay(steps: [], items: [drops], logs: logs, times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(day.blocks.map { $0.items.first?.isDone } == [true, false, false])
    }

    // MARK: To do v2 words

    private func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    @Test func summarySaysWhatsLeftAndWhatsNext() {
        let (steps, items) = sample
        let at = TestTime.date(26, 8)
        let fresh = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(fresh.summary(time: clock) == TodoDay.Summary(statement: "6 things left for the morning.", line: "Next: Wash face."))

        let wash = steps[0]
        let one = TodoDay(steps: steps, items: items, logs: [log(.routineDone, .routine(.morning), step: wash.id, at: at)],
                          times: TodoDay.defaultTimes, now: at.addingTimeInterval(60), calendar: calendar)
        #expect(one.summary(time: clock).statement == "5 things left for the morning.")
        #expect(one.summary(time: clock).line == "Next: Put on moisturizer.")
        #expect(one.blocks[0].status == "1 of 6")
        #expect(abs(one.blocks[0].fraction - 1.0 / 6.0) < 0.001)
        #expect(one.blocks[0].next?.label == "Put on moisturizer")
    }

    @Test func summaryWhenAllDoneAndWhenEmpty() {
        let (steps, items) = sample
        let at = TestTime.date(26, 20)
        let bed = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(bed.summary(time: clock).statement == "\(bed.blocks.last!.items.count) things left for bedtime.")
        var logs: [LogEntry] = []
        for item in bed.blocks.last!.items {
            switch item.kind {
            case .step(let s): logs.append(log(.routineDone, .routine(.evening), step: s.id, at: at))
            case .supplement(let p): logs.append(log(.supplement, .supplement(.taken), step: p.id, at: at, note: "bedtime"))
            case .skin: for s in bed.skin!.steps { for _ in 0..<3 { logs.append(log(.routineDone, .routine(.evening), step: s.id, at: at)) } }
            }
        }
        let done = TodoDay(steps: steps, items: items, logs: logs, times: TodoDay.defaultTimes, now: at.addingTimeInterval(60), calendar: calendar)
        #expect(done.summary(time: clock) == TodoDay.Summary(statement: "All done for today.", line: "Morning list starts at 7:30 AM."))
        #expect(done.blocks.last?.status == "Done")

        let empty = TodoDay(steps: [], items: [], logs: [], times: TodoDay.defaultTimes, now: TestTime.date(26, 8), calendar: calendar)
        if empty.open != nil {
            #expect(empty.summary(time: clock).statement.hasPrefix("Nothing on the list"))
        }
    }

    @Test func skinDotsShowDoneDueAndOptional() {
        let (steps, items) = sample
        let skin = steps.filter { $0.category == .apply && $0.planItemID != nil }
        let at = TestTime.date(26, 9)
        let none = TodoDay(steps: steps, items: items, logs: [], times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(none.skin?.pips == [.due, .due, .due, .optional])
        let one = TodoDay(steps: steps, items: items, logs: [log(.routineDone, .routine(.morning), step: skin[0].id, at: at)],
                          times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(one.skin?.pips == [.done, .due, .due, .optional])
        let five = (0..<5).map { _ in log(.routineDone, .routine(.morning), step: skin[0].id, at: at) }
        let extra = TodoDay(steps: steps, items: items, logs: five, times: TodoDay.defaultTimes, now: at, calendar: calendar)
        #expect(extra.skin?.pips == [.done, .done, .done, .done, .done])
    }
}

/// Ticking a whole block, the restore, the provider's words, and the upgrade.
struct TodoStoreTests {
    @Test func allDoneTicksTheWholeBlock() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 19))
        let routine = RoutineStore(modelContainer: harness.container)
        _ = try await routine.add(name: "Bath", time: .evening, child: harness.child.id)
        _ = try await routine.add(name: "Pajamas", time: .evening, child: harness.child.id)
        let plans = CarePlanStore(modelContainer: harness.container)
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [
            PlanItemDraft(kind: .supplement, text: "ADD Drops", dose: "8 drops", frequency: "2x per day", sourceLine: "ADD Drops 8 drops, 2x per day"),
        ])
        for item in try await plans.items(plan: draft.id) { try await plans.setConfirmed(item.id, true) }
        _ = try await plans.start(draft.id)
        let drops = try #require(try await plans.items(plan: draft.id).first)
        try await plans.setGiving(drops.id, true)

        let clock = harness.clock
        let actions = TodoActions(container: harness.container, times: { TodoDay.defaultTimes }, now: { clock.now })
        let ticked = try await actions.completeBlock(.bedtime, child: harness.child.id, source: .notification)
        #expect(ticked == 3)
        let day = try await actions.day(child: harness.child.id)
        #expect(day.blocks.first { $0.block == .bedtime }?.isDone == true)
        #expect(day.blocks.first { $0.block == .morning }?.items.first?.isDone == false)
        #expect(try await actions.completeBlock(.bedtime, child: harness.child.id, source: .notification) == 0)
    }

    @Test func restoreBringsBackTheParentsOwnSteps() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let routine = RoutineStore(modelContainer: harness.container)
        let bath = try await routine.add(name: "Bath", time: .evening, child: harness.child.id)
        let logs = LogStore(modelContainer: harness.container)
        _ = try await logs.logRoutineStep(bath.id, source: .app)
        let plans = CarePlanStore(modelContainer: harness.container)
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: LegacyPlanFixture.items)
        for item in try await plans.items(plan: draft.id) { try await plans.setConfirmed(item.id, true) }
        _ = try await plans.start(draft.id)
        try await plans.removeAllPlansAndSteps(child: harness.child.id)
        #expect(try await routine.steps(child: harness.child.id).isEmpty)

        let restored = try await plans.restoreOwnSteps(child: harness.child.id)
        #expect(restored == 1)
        let back = try await routine.steps(child: harness.child.id)
        #expect(back.map(\.id) == [bath.id])
        #expect(try await logs.allLive().contains { $0.routineStepID == bath.id })
    }

    @Test func providerWordsAreNeverCut() async throws {
        let line = "Patch Testing: Apply a quarter size amount of a new topical to the inside of the forearm and wait for several hours to assess the skin’s reaction. If Cal complains of itching, burning or pain, wash the topical off immediately."
        let item = PlanItemInfo(id: UUID(), planID: UUID(), kind: .topicalStep, text: "Patch Testing: Apply a quarter size amount of a new topical",
                                dose: nil, frequency: nil, timing: nil, duration: nil, sourcePage: 5, sourceLine: line, isConfirmed: true, order: 0)
        #expect(item.providerWords == line)

        // A cut quote gets its whole paragraph back from the original, never something shorter or different.
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let plans = CarePlanStore(modelContainer: harness.container)
        let short = String(line.prefix(140))
        let draft = try await plans.createDraft(child: harness.child.id, provider: "", items: [
            PlanItemDraft(kind: .topicalStep, text: short, sourcePage: 5, sourceLine: short),
        ])
        let saved = try #require(try await plans.items(plan: draft.id).first)
        try await plans.setSourceParagraph(saved.id, "Something else entirely, longer than the line, that doesn't start with it at all.")
        #expect(try await plans.items(plan: draft.id).first?.sourceParagraph == nil)
        try await plans.setSourceParagraph(saved.id, line)
        #expect(try await plans.items(plan: draft.id).first?.providerWords == line)
    }

    @Test func plainWordsKeepEveryNumberAndBrand() {
        let source = "Step 3: Jojoba oil + Neem oil. Start with 50:50 ratio and work up, as tolerated. Kate Blanc Brand on Amazon."
        #expect(PlainWords.isFaithful("Start with a 50:50 mix of Jojoba oil and Neem oil. Use more as the skin allows. Kate Blanc brand, on Amazon. This is step 3.", to: source))
        #expect(!PlainWords.isFaithful("Start with a 60:40 mix of Jojoba oil and Neem oil. Kate Blanc brand, on Amazon. Step 3.", to: source))
        #expect(!PlainWords.isFaithful("Start with a 50:50 mix of oils. Step 3.", to: source))
        #expect(!PlainWords.isFaithful("Commence application of Jojoba and Neem at a 50:50 proportionality, subsequently titrating upward contingent upon tolerability. Kate Blanc Amazon step 3.", to: source))
    }

    @Test func v6DataSurvivesTheUpgrade() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("migration-v7-\(UUID().uuidString)").appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }
        let childID = UUID()
        var stepID = UUID(), itemID = UUID(), logID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV6.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(old)
            let child = SchemaV6.Child(id: childID, name: "Cal", colorTag: "sage")
            context.insert(child)
            let plan = SchemaV6.CarePlan(childID: childID, provider: "Dr. Rivera")
            plan.statusRaw = CarePlanStatus.active.rawValue
            context.insert(plan)
            let item = SchemaV6.PlanItem(planID: plan.id, childID: childID, kind: .supplement, text: "ADD Drops", dose: "8 drops",
                                         frequency: "3x daily", sourceLine: "ADD Drops 8 drops, 3x daily", order: 0)
            item.isConfirmed = true
            itemID = item.id
            context.insert(item)
            let step = SchemaV6.RoutineStep(childID: childID, name: "Bath", time: .evening, order: 0)
            step.label = "Take a bath"
            stepID = step.id
            context.insert(step)
            let log = SchemaV6.LogEvent(child: child, type: .supplement, value: .supplement(.started), note: nil, timestamp: .now,
                                        loggedBy: "Mom", entrySource: .app, routineStepID: item.id)
            logID = log.id
            context.insert(log)
            try context.save()
        }
        let context = ModelContext(try CaliCareModelContainer.make(url: url))
        let item = try #require(try context.fetch(FetchDescriptor<PlanItem>()).first)
        #expect(item.id == itemID && item.text == "ADD Drops" && item.dose == "8 drops")
        #expect(item.isGiving == nil && item.givingTimesRaw == nil)
        let step = try #require(try context.fetch(FetchDescriptor<RoutineStep>()).first)
        #expect(step.id == stepID && step.name == "Bath" && step.label == "Take a bath")
        let log = try #require(try context.fetch(FetchDescriptor<LogEvent>()).first)
        #expect(log.id == logID && log.routineStepID == itemID)
    }
}

struct FixturePlainTests {
    @Test func everyFixturePlainLineIsFaithful() {
        for (start, plain) in LegacyPlanFixture.plain {
            let line = try! #require(LegacyPlanFixture.items.compactMap(\.sourceLine).first { $0.hasPrefix(start) })
            #expect(PlainWords.isFaithful(plain, to: line), "\(start): grade \(ReadingGrade.grade(plain))")
        }
    }
}

struct SourceParagraphTests {
    @Test func findsTheRestOfACutLine() {
        let text = """
        --- Page 5 ---
        Patch Testing: Apply a quarter size amount of a new topical to the inside of the forearm and wait for
        several hours to assess the skin’s reaction. If Cal complains of itching, burning or pain, wash the topical
        off immediately.

        • Continue a supportive topical routine.
        """
        let cut = "Patch Testing: Apply a quarter size amount of a new topical to the inside of the forearm and wait for several hours to assess the skin’s reaction."
        let found = SourceParagraph.find(cut, in: text)
        #expect(found?.hasSuffix("wash the topical off immediately.") == true)
        #expect(found?.hasPrefix("Patch Testing:") == true)
        #expect(SourceParagraph.find("Continue a supportive topical routine.", in: text) == nil)
        #expect(SourceParagraph.find("Not in the plan at all", in: text) == nil)
        // Never runs into another item's words.
        let joined = "Rinse with water. Then pat dry. Seal with oil."
        #expect(SourceParagraph.find("Rinse with water.", in: joined, otherLines: ["Seal with oil."]) == "Rinse with water. Then pat dry.")
    }
}
