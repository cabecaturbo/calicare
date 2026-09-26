import Core
import Foundation
import Testing

struct WeekOverviewTests {
    private let calendar = TestTime.calendar
    private let today = CareDay(year: 2026, month: 9, day: 26)

    private func entry(_ type: LogType, _ value: LogValue? = nil, _ date: Date) -> LogEntry {
        LogEntry(childID: nil, type: type, value: value, timestamp: date)
    }

    @Test func sevenDaysOldestFirst() {
        let days = WeekOverview.days(ending: today, events: [], calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first?.day == CareDay(year: 2026, month: 9, day: 20))
        #expect(days.last?.day == today)
    }

    @Test func emptyDaysAreNeutral() {
        let days = WeekOverview.days(ending: today, events: [], calendar: calendar)
        #expect(days.allSatisfy { !$0.hasLogs && $0.night == nil && $0.skin == nil })
    }

    @Test func nightUsesRatingThenWakeUps() {
        let events = [
            entry(.nightRating, .night(.rough), TestTime.date(26, 7)),
            entry(.itchEpisode, nil, TestTime.date(25, 2)),
            entry(.itchEpisode, nil, TestTime.date(25, 3)),
            entry(.itchEpisode, nil, TestTime.date(24, 3)),
        ]
        let days = WeekOverview.days(ending: today, events: events, calendar: calendar)
        #expect(days[6].night == .high)
        #expect(days[5].night == .medium)
        #expect(days[4].night == .low)
        #expect(days[3].night == nil)
    }

    @Test func skinCountsItchesAndFlares() {
        let events = [
            // A day with only a good night rating is calm.
            entry(.nightRating, .night(.good), TestTime.date(26, 7)),
            entry(.flare, nil, TestTime.date(25, 12)),
            entry(.flare, nil, TestTime.date(24, 12)),
            entry(.flare, nil, TestTime.date(24, 13)),
        ]
        let days = WeekOverview.days(ending: today, events: events, calendar: calendar)
        #expect(days[6].skin == .low)
        #expect(days[5].skin == .medium)
        #expect(days[4].skin == .high)
        #expect(days[3].skin == nil)
    }

    @Test func levelsAreOrdered() {
        #expect(CareLevel.low < .medium)
        #expect(CareLevel.medium < .high)
    }
}
