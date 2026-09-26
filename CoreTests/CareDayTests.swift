import Core
import Foundation
import Testing

struct CareDayTests {
    private let calendar = TestTime.calendar
    private let sept26 = CareDay(year: 2026, month: 9, day: 26)

    @Test(arguments: [(2, 0), (6, 59), (7, 0), (12, 0), (18, 59)])
    func earlyAndDaytimeStayOnTheSameDate(hour: Int, minute: Int) {
        let day = CareDay.containing(TestTime.date(26, hour, minute), calendar: calendar)
        #expect(day == sept26)
    }

    @Test(arguments: [19, 22, 23])
    func eveningBelongsToTheNextMorning(hour: Int) {
        let day = CareDay.containing(TestTime.date(25, hour), calendar: calendar)
        #expect(day == sept26)
    }

    @Test func intervalsRunSevenToSeven() {
        #expect(sept26.interval(calendar: calendar) == DateInterval(start: TestTime.date(25, 19), end: TestTime.date(26, 19)))
        #expect(sept26.nightInterval(calendar: calendar) == DateInterval(start: TestTime.date(25, 19), end: TestTime.date(26, 7)))
        #expect(sept26.daytimeInterval(calendar: calendar) == DateInterval(start: TestTime.date(26, 7), end: TestTime.date(26, 19)))
    }

    @Test func boundariesAreHalfOpen() {
        #expect(sept26.contains(TestTime.date(25, 19), calendar: calendar))
        #expect(!sept26.contains(TestTime.date(26, 19), calendar: calendar))
    }

    @Test func nightStartCrossesMonthBoundary() {
        let oct1 = CareDay(year: 2026, month: 10, day: 1)
        #expect(oct1.interval(calendar: calendar).start == TestTime.date(2026, 9, 30, 19))
    }

    @Test func nightAcrossDaylightSavingEndIsThirteenHours() {
        // US clocks fall back at 2 AM on Nov 1, 2026.
        let nov1 = CareDay(year: 2026, month: 11, day: 1)
        let night = nov1.nightInterval(calendar: calendar)
        #expect(night.start == TestTime.date(2026, 10, 31, 19))
        #expect(night.end == TestTime.date(2026, 11, 1, 7))
        #expect(night.duration == 13 * 3600)
    }

    @Test func addingDays() {
        #expect(sept26.adding(days: 5, calendar: calendar) == CareDay(year: 2026, month: 10, day: 1))
        #expect(sept26.adding(days: -1, calendar: calendar) == CareDay(year: 2026, month: 9, day: 25))
    }
}

struct CareDayDaytimeTests {
    @Test func daytimeIsSevenToSeven() {
        let day = CareDay(year: 2026, month: 9, day: 26)
        #expect(day.isDaytime(TestTime.date(26, 7), calendar: TestTime.calendar))
        #expect(day.isDaytime(TestTime.date(26, 18, 59), calendar: TestTime.calendar))
        #expect(!day.isDaytime(TestTime.date(26, 19), calendar: TestTime.calendar))
        #expect(!day.isDaytime(TestTime.date(26, 6, 59), calendar: TestTime.calendar))
    }
}
