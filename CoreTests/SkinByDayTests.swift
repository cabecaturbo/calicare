import Core
import Foundation
import Testing

/// Every "skin by day" view reads only the daily answer.
struct SkinByDayTests {
    private let child = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    private let weekEnding = CareDay(year: 2026, month: 9, day: 26)

    private func entry(_ type: LogType, _ value: LogValue? = nil, _ date: Date) -> LogEntry {
        LogEntry(childID: child.id, type: type, value: value, timestamp: date)
    }

    private var events: [LogEntry] {
        [
            entry(.skinToday, .skin(.veryRough), TestTime.date(26, 18)),
            entry(.skinToday, .skin(.calm), TestTime.date(25, 18)),
            entry(.flare, nil, TestTime.date(24, 12)),
            entry(.flare, nil, TestTime.date(24, 13)),
        ]
    }

    @Test func weeklyCardCarriesTheAnswerStep() throws {
        let report = WeeklyReport(child: child, weekEnding: weekEnding, events: events, calendar: TestTime.calendar)
        let card = WeeklyCard(report: report, calendar: TestTime.calendar)
        #expect(card.days.map(\.skin) == [nil, nil, nil, nil, nil, 1, 5])

        let url = try #require(card.url)
        #expect(WeeklyCard(url: url) == card)
    }

    @Test func weeklyCardLinksFromBeforeSkinTodayShowNoSkin() throws {
        let old = #"{"l":"M","n":1,"s":2}"#
        let day = try JSONDecoder().decode(WeeklyCard.Day.self, from: Data(old.utf8))
        #expect(day.night == 1)
        #expect(day.skin == nil)
    }

    @Test func doctorReportUsesTheAnswer() {
        let range = DoctorReport.Range(first: CareDay(year: 2026, month: 9, day: 24), last: weekEnding)
        let report = DoctorReport(child: child, range: range, events: events, calendar: TestTime.calendar, locale: Locale(identifier: "en_US"))
        #expect(report.days.map(\.skin) == [nil, .calm, .veryRough])
    }

    @Test func skinOnlyChangesTheHeadlineWhenBothWeeksAnswered() {
        // Same nights both weeks; this week's skin is much harder, but last week has no answers.
        var logs: [LogEntry] = []
        for day in 13...26 {
            logs.append(entry(.nightRating, .night(.okay), TestTime.date(day, 7)))
        }
        for day in 20...26 {
            logs.append(entry(.skinToday, .skin(.veryRough), TestTime.date(day, 18)))
        }
        let unanswered = WeeklyReport(child: child, weekEnding: weekEnding, events: logs, calendar: TestTime.calendar)
        #expect(unanswered.headline == .aboutTheSame)

        for day in 13...19 {
            logs.append(entry(.skinToday, .skin(.calm), TestTime.date(day, 18)))
        }
        let answered = WeeklyReport(child: child, weekEnding: weekEnding, events: logs, calendar: TestTime.calendar)
        #expect(answered.headline == .harder)
    }
}
