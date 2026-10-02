import Core
import Foundation
import Testing

/// Plan's Supplements: only the plan's supplements and its own rules.
struct SupplementPlanTests {
    private let child = UUID()
    private let calendar = TestTime.calendar

    private func item(_ text: String, dose: String? = nil, frequency: String? = nil, line: String? = nil, order: Int) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: .supplement, text: text, dose: dose, frequency: frequency, timing: nil,
                     duration: nil, sourcePage: 2, sourceLine: line ?? text, isConfirmed: true, order: order)
    }

    private func log(_ event: SupplementEvent, _ item: PlanItemInfo, _ day: Int, _ hour: Int = 8) -> LogEntry {
        LogEntry(childID: child, type: .supplement, value: .supplement(event), timestamp: TestTime.date(day, hour), routineStepID: item.id)
    }

    private var example: (rule: PlanItemInfo, probiotic: PlanItemInfo, vitaminD: PlanItemInfo, herb: PlanItemInfo, after: PlanItemInfo) {
        (
            item("Add one at a time, 3–5 days apart", line: "Add one at a time, 3–5 days apart. Start with a drop.", order: 0),
            item("Probiotic, Brand A", dose: "1/4 tsp", frequency: "once daily", order: 1),
            item("Vitamin D3, Brand B", frequency: "daily", order: 2),
            item("Antimicrobial herb, Brand C", dose: "2 drops", frequency: "twice daily",
                 line: "Antimicrobial herb, Brand C, 2 drops, twice daily, rotate after 3 weeks", order: 3),
            item("Start probiotic 2 weeks after antimicrobial", line: "Start probiotic 2 weeks after antimicrobial.", order: 4)
        )
    }

    @Test func readsThePlansWords() {
        #expect(SupplementPlan.daysApart("add one at a time, 3–5 days apart") == 3)
        #expect(SupplementPlan.daysApart("one at a time, 4 days apart") == 4)
        #expect(SupplementPlan.daysApart("one at a time") == nil)
        #expect(SupplementPlan.perDay("twice daily") == 2)
        #expect(SupplementPlan.perDay("once daily") == 1)
        #expect(SupplementPlan.perDay("3x/day") == 3)
        #expect(SupplementPlan.perDay("daily") == 1)
        #expect(SupplementPlan.perDay("3x/week") == nil)
    }

    @Test func beforeAnythingStarts() {
        let e = example
        let plan = SupplementPlan(items: [e.rule, e.probiotic, e.vitaminD, e.herb, e.after], logs: [], now: TestTime.date(26, 9), calendar: calendar)
        #expect(plan.rows.map(\.item.text) == ["Probiotic, Brand A", "Vitamin D3, Brand B", "Antimicrobial herb, Brand C"])
        #expect(plan.rules == ["Add one at a time, 3–5 days apart", "Start probiotic 2 weeks after antimicrobial"])
        #expect(plan.rows[0].waitingFor == "Starts 2 weeks after Antimicrobial herb, Brand C starts")
        #expect(plan.rows[1].canStartAfter == nil)
        #expect(plan.rows[2].perDay == 2)
    }

    @Test func spacingTheProbioticAfterTheHerbAndRotation() {
        let e = example
        let logs = [log(.started, e.herb, 1), log(.taken, e.herb, 26, 8), log(.started, e.vitaminD, 5)]
        let plan = SupplementPlan(items: [e.rule, e.probiotic, e.vitaminD, e.herb, e.after], logs: logs, now: TestTime.date(26, 12), calendar: calendar)
        let probiotic = plan.rows[0], vitaminD = plan.rows[1], herb = plan.rows[2]
        // 3 days after the latest start (Sep 5 → Sep 8), but 2 weeks after the herb (Sep 1 → Sep 15) wins.
        #expect(probiotic.canStartAfter == TestTime.date(15, 8))
        #expect(probiotic.waitingFor == nil)
        #expect(vitaminD.isActive)
        #expect(herb.takenToday == 1)
        #expect(herb.rotateOn == TestTime.date(22, 8))
    }

    @Test func stoppedIsOnlyAfterTheLatestStart() {
        let e = example
        let logs = [log(.started, e.vitaminD, 1), log(.stopped, e.vitaminD, 10), log(.started, e.vitaminD, 20)]
        let plan = SupplementPlan(items: [e.vitaminD], logs: logs, now: TestTime.date(26, 12), calendar: calendar)
        #expect(plan.rows[0].isActive)
        #expect(plan.rows[0].started == TestTime.date(20, 8))
    }
}
