import Core
import Foundation
import Testing

/// Progress › Month: calendar month edges, partial months, time zones, headlines.
struct MonthlyReportTests {
    private let child = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    private let calendar = TestTime.calendar

    private func night(_ rating: NightRating, _ year: Int, _ month: Int, _ day: Int) -> LogEntry {
        LogEntry(childID: child.id, type: .nightRating, value: .night(rating), timestamp: TestTime.date(year, month, day, 7))
    }

    private func nights(_ rating: NightRating, month: Int, days: ClosedRange<Int>) -> [LogEntry] {
        days.map { night(rating, 2026, month, $0) }
    }

    @Test func coversTheCalendarMonthThroughToday() {
        let report = MonthlyReport(child: child, year: 2026, month: 9, through: CareDay(year: 2026, month: 9, day: 27), events: [], calendar: calendar)
        #expect(report.days.count == 27)
        #expect(report.days.first?.day == CareDay(year: 2026, month: 9, day: 1))
        #expect(report.headline == .notEnoughLogs)
        #expect(report.range == DoctorReport.Range(first: CareDay(year: 2026, month: 9, day: 1), last: CareDay(year: 2026, month: 9, day: 27)))

        let full = MonthlyReport(child: child, year: 2026, month: 8, through: CareDay(year: 2026, month: 9, day: 27), events: [], calendar: calendar)
        #expect(full.days.count == 31)
    }

    @Test func aLateNightItchCountsForTheNextCareDay() {
        // 11 PM on September 30 belongs to the care day of October 1.
        let itch = LogEntry(childID: child.id, type: .itchEpisode, timestamp: TestTime.date(2026, 9, 30, 23))
        let today = CareDay(year: 2026, month: 10, day: 5)
        let september = MonthlyReport(child: child, year: 2026, month: 9, through: today, events: [itch], calendar: calendar)
        let october = MonthlyReport(child: child, year: 2026, month: 10, through: today, events: [itch], calendar: calendar)
        #expect(september.itchyWakeUps == 0)
        #expect(october.itchyWakeUps == 1)
    }

    @Test func timeZoneDecidesTheMonth() {
        // 6 AM UTC on October 1 is 11 PM on September 30 in Los Angeles (October 1's care day)
        // but 3 PM on October 1 in Tokyo.
        let moment = Date(timeIntervalSince1970: 1_790_834_400) // 2026-10-01 06:00 UTC
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(CareDay.containing(moment, calendar: calendar) == CareDay(year: 2026, month: 10, day: 1))
        #expect(CareDay.containing(moment, calendar: tokyo) == CareDay(year: 2026, month: 10, day: 1))
        let early = Date(timeIntervalSince1970: 1_790_812_800) // 2026-10-01 00:00 UTC: 5 PM Sep 30 in LA
        #expect(CareDay.containing(early, calendar: calendar) == CareDay(year: 2026, month: 9, day: 30))
    }

    @Test func aPartialMonthComparesByAverages() {
        let events = nights(.rough, month: 8, days: 1...31) + nights(.good, month: 9, days: 1...10)
        let report = MonthlyReport(child: child, year: 2026, month: 9, through: CareDay(year: 2026, month: 9, day: 10), events: events, calendar: calendar)
        #expect(report.headline == .calmer)
        #expect(report.goodNights == 10)
        #expect(report.worthWatching == nil)
    }

    @Test func firstMonthAndHarderMonth() {
        let first = MonthlyReport(child: child, year: 2026, month: 9, through: CareDay(year: 2026, month: 9, day: 30),
                                  events: nights(.good, month: 9, days: 1...10), calendar: calendar)
        #expect(first.headline == .firstMonth)

        let events = nights(.good, month: 8, days: 1...20) + nights(.rough, month: 9, days: 1...12)
        let harder = MonthlyReport(child: child, year: 2026, month: 9, through: CareDay(year: 2026, month: 9, day: 30), events: events, calendar: calendar)
        #expect(harder.headline == .harder)
        #expect(harder.worthWatching == "More rough nights this month.")
    }

    @Test func januaryLooksBackToDecember() {
        let events = nights(.okay, month: 12, days: 1...10).map {
            LogEntry(childID: child.id, type: .nightRating, value: $0.value, timestamp: calendar.date(byAdding: .year, value: -1, to: $0.timestamp)!)
        } + (1...8).map { LogEntry(childID: child.id, type: .nightRating, value: .night(.okay), timestamp: TestTime.date(2026, 1, $0, 7)) }
        let report = MonthlyReport(child: child, year: 2026, month: 1, through: CareDay(year: 2026, month: 1, day: 31), events: events, calendar: calendar)
        #expect(report.headline == .aboutTheSame)
    }
}
