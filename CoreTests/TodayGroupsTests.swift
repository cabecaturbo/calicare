import Core
import Foundation
import Testing

/// One boundary for Today's list: 7 PM to 7 AM is night.
struct TodayGroupsTests {
    let calendar = TestTime.calendar
    /// The care day Sat Sep 26: its night is Fri 7 PM to Sat 7 AM.
    var day: CareDay { CareDay.containing(TestTime.date(26, 12), calendar: calendar) }

    func log(_ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> LogEntry {
        LogEntry(childID: UUID(), type: .itchEpisode, timestamp: TestTime.date(dayOfMonth, hour, minute))
    }

    @Test func byDayLastNightIsItsOwnGroup() {
        let entries = [log(26, 9, 10), log(26, 1, 52), log(25, 23, 40)]
        let groups = TodayGroups(entries: entries, day: day, now: TestTime.date(26, 14), calendar: calendar)
        #expect(!groups.isNight)
        #expect(groups.currentTitle == "Today")
        #expect(groups.current.map(\.timestamp) == [TestTime.date(26, 9, 10)])
        #expect(groups.lastNight.count == 2)
    }

    @Test func atNightOnlyTonight() {
        let tonight = CareDay.containing(TestTime.date(26, 21), calendar: calendar)
        let entries = [log(26, 23, 5), log(26, 20, 15)]
        let groups = TodayGroups(entries: entries, day: tonight, now: TestTime.date(26, 23, 30), calendar: calendar)
        #expect(groups.isNight)
        #expect(groups.currentTitle == "Tonight")
        #expect(groups.current.count == 2)
        #expect(groups.lastNight.isEmpty)
    }

    @Test func sevenPMStartsTheNight() {
        let tonight = CareDay.containing(TestTime.date(26, 19), calendar: calendar)
        let groups = TodayGroups(entries: [], day: tonight, now: TestTime.date(26, 19), calendar: calendar)
        #expect(groups.isNight)
        #expect(NightMode.isActive(at: TestTime.date(26, 19), calendar: calendar))
    }
}
