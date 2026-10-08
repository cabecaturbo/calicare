import Core
import Foundation
import SwiftData
import Testing

/// Plan v4: the star (week and next visit), Coming up, and dose steps.
struct PlanStarTests {
    private let calendar = TestTime.calendar
    private let child = UUID()
    private let planID = UUID()
    /// Today: Oct 7, 2026, 10 AM (Los Angeles).
    private let now = TestTime.date(2026, 10, 7, 10)

    private func plan(started: Date, length: Int? = nil) -> CarePlanInfo {
        CarePlanInfo(id: planID, childID: child, provider: "Dr. Rivera", planDate: nil, sourceFileName: nil,
                     status: .active, startedAt: started, endedAt: nil, lengthWeeks: length)
    }

    private func visit(_ date: Date) -> VisitInfo {
        VisitInfo(id: UUID(), childID: child, date: date, provider: "Dr. Rivera", notes: nil)
    }

    private func supplement(_ text: String, order: Int = 0, dose: String? = nil, giving: Bool? = true,
                            steps: [DoseStep] = []) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: planID, kind: .supplement, text: text, dose: dose, frequency: "2x per day",
                     timing: nil, duration: nil, sourcePage: 1, sourceLine: text, isConfirmed: true, order: order,
                     isGiving: giving, doseSteps: steps)
    }

    private func comingUp(_ items: [PlanItemInfo], visits: [VisitInfo] = [], logs: [LogEntry] = []) -> ComingUp {
        ComingUp(items: items, visits: visits,
                 supplements: SupplementPlan(items: items, logs: logs, now: now, calendar: calendar),
                 now: now, calendar: calendar)
    }

    // MARK: - The star

    @Test func weekOfTheLengthWithProgress() {
        let star = PlanStar(plan: plan(started: TestTime.date(2026, 9, 29, 9), length: 12), visits: [], now: now, calendar: calendar)
        #expect(star.title == "Week 2 of 12")
        #expect(star.progress == 9.0 / 84) // Sep 29 to Oct 7: day 9 of 84
        #expect(star.nextVisit == nil)
    }

    @Test func noLengthIsJustTheWeek() {
        let star = PlanStar(plan: plan(started: TestTime.date(2026, 9, 29, 9)), visits: [], now: now, calendar: calendar)
        #expect(star.title == "Week 2")
        #expect(star.progress == nil)
    }

    @Test func theWeekStopsAtTheLength() {
        let star = PlanStar(plan: plan(started: TestTime.date(2026, 6, 1, 9), length: 12), visits: [], now: now, calendar: calendar)
        #expect(star.title == "Week 12 of 12")
    }

    @Test func nextVisitIsTheSoonestAhead() {
        let visits = [visit(TestTime.date(2026, 9, 20, 10)), visit(TestTime.date(2026, 11, 20, 10)), visit(TestTime.date(2026, 10, 26, 10))]
        let star = PlanStar(plan: plan(started: now), visits: visits, now: now, calendar: calendar)
        #expect(star.nextVisit == "Next visit Oct 26, in 3 weeks")
    }

    @Test func theSuggestedLengthIsThePlansLongestStatedDuration() {
        let probiotic = PlanItemInfo(id: UUID(), planID: planID, kind: .supplement, text: "Probiotic", dose: "1/4 tsp",
                                     frequency: nil, timing: nil, duration: "3 months", sourcePage: 1, sourceLine: nil,
                                     isConfirmed: true, order: 0)
        let topical = PlanItemInfo(id: UUID(), planID: planID, kind: .topicalStep,
                                   text: "Continue a supportive topical routine for 60-90 days past clear skin", dose: nil,
                                   frequency: nil, timing: nil, duration: nil, sourcePage: 1, sourceLine: nil,
                                   isConfirmed: true, order: 1)
        #expect(PlanStar.suggestedWeeks([probiotic]) == 13)
        #expect(PlanStar.suggestedWeeks([probiotic, topical]) == 13)
        #expect(PlanStar.suggestedWeeks([supplement("Zinc", dose: "2 ml")]) == nil)
    }

    // MARK: - Coming up

    @Test func nothingStoredMeansNothingComingUp() {
        // "Work up slowly" with no numbers: no step, no date, nothing shown.
        let coptis = supplement("Coptis. Start with a single drop and work up slowly", dose: "8 drops")
        #expect(comingUp([coptis]).all.isEmpty)
    }

    @Test func onlyFutureStepsShowAndTheCurrentOneIsTheLatestPast() {
        let coptis = supplement("ADD Coptis", dose: "8 drops", steps: [
            DoseStep(amount: "1 drop", startDate: TestTime.date(2026, 9, 28, 0)),
            DoseStep(amount: "2 drops", startDate: TestTime.date(2026, 10, 5, 0)),
            DoseStep(amount: "4 drops", startDate: TestTime.date(2026, 10, 12, 0)),
        ])
        let up = comingUp([coptis])
        #expect(up.all.map(\.text) == ["Coptis goes to 4 drops"])
        #expect(up.all.first?.reason == nil)
        #expect(coptis.dose(on: now, calendar: calendar) == "2 drops")
        #expect(coptis.dose(on: TestTime.date(2026, 10, 12, 8), calendar: calendar) == "4 drops")
        #expect(supplement("Zinc", dose: "2 ml").dose(on: now, calendar: calendar) == "2 ml")
    }

    @Test func everyShownDoseAndDateIsAStoredOne() {
        let steps = [DoseStep(amount: "3 drops", startDate: TestTime.date(2026, 10, 9, 0)),
                     DoseStep(amount: "5 drops", startDate: TestTime.date(2026, 10, 20, 0))]
        let coptis = supplement("ADD Coptis", dose: "8 drops", steps: steps)
        let visitDate = TestTime.date(2026, 10, 26, 10)
        let up = comingUp([coptis, supplement("Zinc", order: 1, dose: "2 ml")], visits: [visit(visitDate)])
        let stored = Set(steps.map(\.startDate) + [visitDate])
        #expect(up.all.allSatisfy { stored.contains($0.date) })
        #expect(up.all.compactMap { $0.text.components(separatedBy: " goes to ").last }.filter { $0.contains("drops") }
            .allSatisfy { amount in steps.contains { $0.amount == amount } })
        #expect(up.all.map(\.text) == ["Coptis goes to 3 drops", "Coptis goes to 5 drops", "Visit with Dr. Rivera"])
    }

    @Test func aStartTheRulesDateShowsWithItsReason() {
        let herb = supplement("Antimicrobial herb, Brand C", dose: "2 drops")
        let probiotic = supplement("Probiotic, Brand A", order: 1, dose: "1/4 tsp", giving: false)
        let rule = PlanItemInfo(id: UUID(), planID: planID, kind: .supplement, text: "Start probiotic 2 weeks after antimicrobial",
                                dose: nil, frequency: nil, timing: "2 weeks after antimicrobial", duration: nil, sourcePage: 2,
                                sourceLine: "Start probiotic 2 weeks after antimicrobial.", isConfirmed: true, order: 2)
        let started = LogEntry(childID: child, type: .supplement, value: .supplement(.started),
                               timestamp: TestTime.date(2026, 10, 1, 9), routineStepID: herb.id)
        let up = comingUp([herb, probiotic, rule], logs: [started])
        let start = try! #require(up.all.first { $0.text.hasPrefix("Start") })
        #expect(start.text == "Start Probiotic, Brand A")
        #expect(start.reason == "2 weeks after Antimicrobial herb, Brand C")
        #expect(calendar.isDate(start.date, inSameDayAs: TestTime.date(2026, 10, 15, 9)))
    }

    @Test func atMostThreeShowWithTheRestKept() {
        let steps = (1...5).map { DoseStep(amount: "\($0 + 1) drops", startDate: TestTime.date(2026, 10, 8 + $0, 0)) }
        let up = comingUp([supplement("ADD Coptis", steps: steps)])
        #expect(up.shown.count == 3)
        #expect(up.hasMore)
        #expect(up.all.count == 5)
    }

    // MARK: - To do and the stores

    @Test func toDoGivesTheCurrentStepsAmountOnItsDay() {
        let coptis = supplement("ADD Coptis", dose: "8 drops", steps: [
            DoseStep(amount: "2 drops", startDate: TestTime.date(2026, 10, 5, 0)),
            DoseStep(amount: "4 drops", startDate: TestTime.date(2026, 10, 12, 0)),
        ])
        func meta(on day: Date) -> String? {
            TodoDay(steps: [], items: [coptis], logs: [], times: [:], now: day, calendar: calendar)
                .blocks.flatMap(\.items).first { $0.label == "Give Coptis" }?.meta
        }
        #expect(meta(on: now) == "2 drops")
        #expect(meta(on: TestTime.date(2026, 10, 12, 8)) == "4 drops")
    }

    @Test func lengthAndDoseStepsAreSavedAndSynced() async throws {
        let harness = try await TestHarness(start: now)
        let clock = harness.clock
        let plans = CarePlanStore(modelContainer: harness.container, now: { clock.now })
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Rivera", items: [
            PlanItemDraft(kind: .supplement, text: "ADD Coptis", dose: "8 drops", frequency: "3x daily"),
        ])
        let item = try #require(try await plans.items(plan: draft.id).first)
        try await plans.setConfirmed(item.id, true)
        try await plans.start(draft.id)

        try await plans.setLength(draft.id, weeks: 12)
        let steps = [DoseStep(amount: "4 drops", startDate: TestTime.date(2026, 10, 12, 0)),
                     DoseStep(amount: "1 drop", startDate: TestTime.date(2026, 10, 1, 0))]
        try await plans.setDoseSteps(item.id, steps)
        #expect(try await plans.activePlan(child: harness.child.id)?.lengthWeeks == 12)
        #expect(try await plans.items(plan: draft.id).first?.doseSteps.map(\.amount) == ["1 drop", "4 drops"])

        let remote = FakeSyncRemote()
        let settings = SyncSettings(suiteName: "test.\(UUID().uuidString)")
        _ = try await SyncEngine(modelContainer: harness.container, remote: remote, settings: settings, now: { clock.now })
            .sync(userID: UUID(), displayName: "Mom")
        #expect(await remote.carePlans[draft.id]?.lengthWeeks == 12)
        #expect(await remote.planItems[item.id]?.doseSteps?.contains("4 drops") == true)
    }
}
