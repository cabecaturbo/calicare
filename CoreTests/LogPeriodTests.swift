import Core
import Foundation
import Testing

/// The Quick Log card: which period a log counts toward (day 7 AM–7 PM, night
/// 7 PM–7 AM), how they're counted, and the words on the card, the summary,
/// and the share text.
struct LogPeriodTests {
    private let calendar = TestTime.calendar
    private let child = UUID()

    private func itch(_ date: Date) -> LogEntry {
        LogEntry(childID: child, type: .itchEpisode, timestamp: date)
    }

    private func night(ending day: Int, _ events: [LogEntry], month: Int = 9, calendar: Calendar? = nil) -> LogPeriod {
        LogPeriod(kind: .night, day: CareDay(year: 2026, month: month, day: day), events: events, calendar: calendar ?? self.calendar)
    }

    private func time(_ date: Date) -> String { CardClock.time(date, calendar: calendar) }
    private func short(_ date: Date) -> String { CardClock.shortTime(date, calendar: calendar) }

    @Test func sevenPMStartsTheNight() {
        let n = night(ending: 26, [itch(TestTime.date(25, 18, 59)), itch(TestTime.date(25, 19, 0))])
        #expect(n.itches == [TestTime.date(25, 19, 0)])
    }

    @Test func sevenAMEndsTheNight() {
        let n = night(ending: 26, [itch(TestTime.date(26, 6, 59)), itch(TestTime.date(26, 7, 0))])
        #expect(n.itches == [TestTime.date(26, 6, 59)])
    }

    @Test func theDayRunsSevenToSeven() {
        let events = [itch(TestTime.date(26, 6, 59)), itch(TestTime.date(26, 7, 0)), itch(TestTime.date(26, 18, 59)), itch(TestTime.date(26, 19, 0))]
        let day = LogPeriod(kind: .day, day: CareDay(year: 2026, month: 9, day: 26), events: events, calendar: calendar)
        #expect(day.itches == [TestTime.date(26, 7, 0), TestTime.date(26, 18, 59)])
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
        #expect(n.itches == [TestTime.date(25, 23, 40), TestTime.date(26, 1, 52), TestTime.date(26, 4, 10)])
        #expect(n.words.count == 3)
    }

    @Test func currentPeriodFollowsTheClock() {
        let at3pm = LogPeriod.current(at: TestTime.date(25, 15), calendar: calendar)
        #expect(at3pm.kind == .day && at3pm.day == CareDay(year: 2026, month: 9, day: 25))
        let at11pm = LogPeriod.current(at: TestTime.date(25, 23), calendar: calendar)
        #expect(at11pm.kind == .night && at11pm.day == CareDay(year: 2026, month: 9, day: 26))
        let at2am = LogPeriod.current(at: TestTime.date(26, 2), calendar: calendar)
        #expect(at2am.kind == .night && at2am.day == CareDay(year: 2026, month: 9, day: 26))
        let at7am = LogPeriod.current(at: TestTime.date(26, 7), calendar: calendar)
        #expect(at7am.kind == .day && at7am.day == CareDay(year: 2026, month: 9, day: 26))
    }

    @Test func lastNightIsTheOneThatEndedThisMorning() {
        #expect(LogPeriod.lastNight(at: TestTime.date(26, 8), calendar: calendar) == CareDay(year: 2026, month: 9, day: 26))
    }

    @Test func springForwardNightIsElevenHours() {
        let n = night(ending: 8, [itch(TestTime.date(2026, 3, 8, 3, 30))], month: 3)
        #expect(n.end.timeIntervalSince(n.start) == 11 * 3600)
        #expect(n.words.count == 1)
    }

    @Test func fallBackNightIsThirteenHours() {
        let first = TestTime.date(2026, 11, 1, 1, 30)
        let n = night(ending: 1, [itch(first), itch(first.addingTimeInterval(3600))], month: 11)
        #expect(n.end.timeIntervalSince(n.start) == 13 * 3600)
        #expect(n.words.count == 2)
    }

    @Test func aTimeZoneChangeUsesThePhonesCurrentZone() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let wakeUp = TestTime.date(26, 4, 30)
        #expect(night(ending: 26, [itch(wakeUp)]).words.count == 1)
        #expect(night(ending: 26, [itch(wakeUp)], calendar: newYork).words.count == 0)
    }

    @Test func cardLines() {
        #expect(PeriodWords(kind: .night, itches: []).line(time: time) == "Tonight: no wake-ups yet.")
        #expect(PeriodWords(kind: .day, itches: []).line(time: time) == "Today: nothing logged yet.")
        let two = PeriodWords(kind: .night, itches: [TestTime.date(26, 1, 52), TestTime.date(25, 23, 40)])
        #expect(two.line(time: time) == "Tonight: 2 wake-ups · last at 1:52 AM")
        #expect(two.spokenLine(time: time) == "2 wake-ups tonight, last at 1:52 AM.")
        let day = PeriodWords(kind: .day, itches: [TestTime.date(26, 15, 10)])
        #expect(day.line(time: time) == "Today: 1 itch · last at 3:10 PM")
        #expect(day.spokenLine(time: time) == "1 itch today, last at 3:10 PM.")
    }

    @Test func summaries() {
        let three = PeriodWords(kind: .night, itches: [TestTime.date(25, 23, 40), TestTime.date(26, 1, 52), TestTime.date(26, 4, 10)])
        #expect(three.summary(shortTime: short) == "Last night: 3 wake-ups (11:40, 1:52, 4:10).")
        #expect(PeriodWords(kind: .night, itches: []).summary(shortTime: short) == "Last night: no wake-ups logged.")
        #expect(PeriodWords(kind: .day, itches: [TestTime.date(26, 9, 10), TestTime.date(26, 15, 40)]).summary(shortTime: short) == "Today: 2 itches (9:10, 3:40).")
    }

    @Test func shareText() {
        let a = TestTime.date(25, 23, 40), b = TestTime.date(26, 1, 52), c = TestTime.date(26, 4, 10)
        #expect(PeriodWords(kind: .night, itches: []).shareText(time: time) == "Last night: no wake-ups logged.")
        #expect(PeriodWords(kind: .night, itches: [b]).shareText(time: time) == "Last night: 1 wake-up, at 1:52 AM.")
        #expect(PeriodWords(kind: .night, itches: [a, b]).shareText(time: time) == "Last night: 2 wake-ups, at 11:40 PM and 1:52 AM.")
        #expect(PeriodWords(kind: .night, itches: [a, b, c]).shareText(time: time) == "Last night: 3 wake-ups, at 11:40 PM, 1:52 AM, and 4:10 AM.")
    }
}
