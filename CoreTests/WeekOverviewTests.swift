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

    @Test func skinComesOnlyFromTheDailyAnswer() {
        let events = [
            entry(.skinToday, .skin(.flaring), TestTime.date(26, 17)),
            entry(.skinToday, .skin(.calm), TestTime.date(25, 18)),
            // Itches and flares never set skin, however many.
            entry(.flare, nil, TestTime.date(24, 12)),
            entry(.flare, nil, TestTime.date(24, 13)),
            entry(.itchEpisode, nil, TestTime.date(24, 14)),
            entry(.nightRating, .night(.good), TestTime.date(23, 7)),
        ]
        let days = WeekOverview.days(ending: today, events: events, calendar: calendar)
        #expect(days[6].skin == .flaring)
        #expect(days[5].skin == .calm)
        #expect(days[4].skin == nil)
        #expect(days[4].hasLogs)
        #expect(days[3].skin == nil)
        #expect(days[3].hasLogs)
        #expect(days[2].skin == nil)
        #expect(!days[2].hasLogs)
    }

    @Test func skinStepsFollowTheIndigoScale() {
        #expect(SkinToday.allCases.map(\.step) == [1, 2, 4, 5])
    }

    @Test func levelsAreOrdered() {
        #expect(CareLevel.low < .medium)
        #expect(CareLevel.medium < .high)
    }
}
