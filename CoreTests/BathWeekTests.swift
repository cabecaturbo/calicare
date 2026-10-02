import Core
import Foundation
import Testing

/// Plan's Baths: the plan's baths, times a week, and what was logged this week.
struct BathWeekTests {
    private let child = UUID()

    private func item(_ text: String, frequency: String? = nil, duration: String? = nil) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: .bath, text: text, dose: nil, frequency: frequency, timing: nil,
                     duration: duration, sourcePage: 1, sourceLine: text, isConfirmed: true, order: 0)
    }

    private func bath(_ item: PlanItemInfo, _ day: Int, _ hour: Int = 19) -> LogEntry {
        LogEntry(childID: child, type: .bath, timestamp: TestTime.date(day, hour), routineStepID: item.id)
    }

    @Test func timesAWeekFromThePlansWords() {
        #expect(BathWeek.perWeek("3x/week") == 3)
        #expect(BathWeek.perWeek("2 times a week") == 2)
        #expect(BathWeek.perWeek("twice weekly") == 2)
        #expect(BathWeek.perWeek("once a week") == 1)
        #expect(BathWeek.perWeek("daily") == nil)
        #expect(BathWeek.perWeek(nil) == nil)
    }

    @Test func countsThisWeeksBathsAndKeepsRulesAsNotes() {
        let oat = item("Oat bath", frequency: "3x/week", duration: "10 minutes")
        let salt = item("Salt bath", frequency: "2x/week")
        let rule = item("Baths (rotate, don't combine)")
        // Sunday, September 27 starts the week in the US; the 26th is last week.
        let week = BathWeek(
            items: [oat, salt, rule],
            logs: [bath(oat, 26), bath(oat, 27), bath(oat, 28), bath(salt, 28, 8)],
            now: TestTime.date(28, 20),
            calendar: TestTime.calendar
        )
        #expect(week.rows.map(\.item.text) == ["Oat bath", "Salt bath"])
        #expect(week.rows.map(\.perWeek) == [3, 2])
        #expect(week.rows.map(\.doneThisWeek) == [2, 1])
        #expect(week.rows[0].lastDone == TestTime.date(28, 19))
        #expect(week.notes == ["Baths (rotate, don't combine)"])
    }

    @Test func aBathLogRemembersWhichBath() async throws {
        let harness = try await TestHarness(start: TestTime.date(28, 19))
        let oat = UUID()
        let entry = try await harness.logs.logBath(oat, child: harness.child.id, source: .app)
        #expect(entry.type == .bath)
        #expect(entry.routineStepID == oat)
    }
}
