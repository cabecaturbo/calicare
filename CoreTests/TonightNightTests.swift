import Core
import Foundation
import Testing

/// Tonight: which night a wake-up counts toward, how they're counted, and the
/// words on the Lock Screen card, the morning summary, and the share text.
struct TonightNightTests {
    private let calendar = TestTime.calendar
    private let child = UUID()

    private func itch(_ date: Date) -> LogEntry {
        LogEntry(childID: child, type: .itchEpisode, timestamp: date)
    }

    private func night(ending day: Int, _ events: [LogEntry], month: Int = 9, calendar: Calendar? = nil) -> TonightNight {
        TonightNight(day: CareDay(year: 2026, month: month, day: day), events: events, calendar: calendar ?? self.calendar)
    }

    private func time(_ date: Date) -> String { TonightClock.time(date, calendar: calendar) }
    private func short(_ date: Date) -> String { TonightClock.shortTime(date, calendar: calendar) }

    @Test func sevenPMStartsTheNight() {
        let n = night(ending: 26, [itch(TestTime.date(25, 18, 59)), itch(TestTime.date(25, 19, 0))])
        #expect(n.wakeUps == [TestTime.date(25, 19, 0)])
    }

    @Test func sevenAMEndsTheNight() {
        let n = night(ending: 26, [itch(TestTime.date(26, 6, 59)), itch(TestTime.date(26, 7, 0))])
        #expect(n.wakeUps == [TestTime.date(26, 6, 59)])
    }

    @Test func countsOnlyItchLogsInOrder() {
        let events = [
            itch(TestTime.date(26, 4, 10)),
            LogEntry(childID: child, type: .flare, timestamp: TestTime.date(26, 2, 0)),
            LogEntry(childID: child, type: .nightRating, value: .night(.rough), timestamp: TestTime.date(26, 6, 0)),
            itch(TestTime.date(25, 23, 40)),
            itch(TestTime.date(26, 1, 52)),
        ]
        let n = night(ending: 26, events)
        #expect(n.count == 3)
        #expect(n.wakeUps == [TestTime.date(25, 23, 40), TestTime.date(26, 1, 52), TestTime.date(26, 4, 10)])
        #expect(n.last == TestTime.date(26, 4, 10))
    }

    @Test func tonightMeansTheNightInProgressOrTheOneComingUp() {
        // 3 PM: tonight is the night ending tomorrow morning.
        #expect(TonightNight.day(at: TestTime.date(25, 15), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
        // 11 PM and 2 AM: the night in progress, ending the 26th.
        #expect(TonightNight.day(at: TestTime.date(25, 23), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
        #expect(TonightNight.day(at: TestTime.date(26, 2), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
        // 7 AM: the next night.
        #expect(TonightNight.day(at: TestTime.date(26, 7), calendar: calendar) == CareDay(year: 2026, month: 9, day: 27))
    }

    @Test func lastNightIsTheOneThatEndedThisMorning() {
        #expect(TonightNight.lastNight(at: TestTime.date(26, 8), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
        #expect(TonightNight.lastNight(at: TestTime.date(26, 18, 59), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
    }

    @Test func springForwardNightIsElevenHours() {
        // March 8, 2026: clocks jump from 2 AM to 3 AM in Los Angeles.
        let n = night(ending: 8, [itch(TestTime.date(2026, 3, 8, 3, 30))], month: 3)
        #expect(n.end.timeIntervalSince(n.start) == 11 * 3600)
        #expect(n.count == 1)
    }

    @Test func fallBackNightIsThirteenHours() {
        // November 1, 2026: 1 AM happens twice.
        let first = TestTime.date(2026, 11, 1, 1, 30)
        let second = first.addingTimeInterval(3600)
        let n = night(ending: 1, [itch(first), itch(second)], month: 11)
        #expect(n.end.timeIntervalSince(n.start) == 13 * 3600)
        #expect(n.count == 2)
    }

    @Test func aTimeZoneChangeUsesThePhonesCurrentZone() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 4:30 AM in Los Angeles is 7:30 AM in New York: last night there has already ended.
        let wakeUp = TestTime.date(26, 4, 30)
        let inLA = TonightNight(day: CareDay(year: 2026, month: 9, day: 26), events: [itch(wakeUp)], calendar: calendar)
        let inNY = TonightNight(day: CareDay(year: 2026, month: 9, day: 26), events: [itch(wakeUp)], calendar: newYork)
        #expect(inLA.count == 1)
        #expect(inNY.count == 0)
    }

    @Test func cardLines() {
        let none = NightWords(wakeUps: [])
        #expect(none.line(time: time) == "No wake-ups yet.")
        #expect(none.spokenLine(time: time) == "No wake-ups tonight yet.")
        let one = NightWords(wakeUps: [TestTime.date(26, 1, 52)])
        #expect(one.line(time: time) == "1 wake-up · last at 1:52 AM")
        let two = NightWords(wakeUps: [TestTime.date(26, 1, 52), TestTime.date(25, 23, 40)])
        #expect(two.line(time: time) == "2 wake-ups · last at 1:52 AM")
        #expect(two.spokenLine(time: time) == "2 wake-ups tonight, last at 1:52 AM.")
    }

    @Test func morningSummary() {
        let three = NightWords(wakeUps: [TestTime.date(25, 23, 40), TestTime.date(26, 1, 52), TestTime.date(26, 4, 10)])
        #expect(three.summary(shortTime: short) == "Last night: 3 wake-ups (11:40, 1:52, 4:10).")
        #expect(NightWords(wakeUps: []).summary(shortTime: short) == "Last night: no wake-ups logged.")
    }

    @Test func shareText() {
        let a = TestTime.date(25, 23, 40), b = TestTime.date(26, 1, 52), c = TestTime.date(26, 4, 10)
        #expect(NightWords(wakeUps: []).shareText(time: time) == "Last night: no wake-ups logged.")
        #expect(NightWords(wakeUps: [b]).shareText(time: time) == "Last night: 1 wake-up, at 1:52 AM.")
        #expect(NightWords(wakeUps: [a, b]).shareText(time: time) == "Last night: 2 wake-ups, at 11:40 PM and 1:52 AM.")
        #expect(NightWords(wakeUps: [a, b, c]).shareText(time: time) == "Last night: 3 wake-ups, at 11:40 PM, 1:52 AM, and 4:10 AM.")
    }
}
