import Core
import Foundation
import SwiftData
import Testing

struct SkinTodayTests {
    @Test func valuesRoundTrip() {
        for answer in SkinToday.allCases {
            #expect(LogValue(type: .skinToday, raw: answer.rawValue) == .skin(answer))
        }
        #expect(LogType.skinToday.accepts(.skin(.flaring)))
        #expect(!LogType.skinToday.accepts(nil))
        #expect(!LogType.skinToday.accepts(.night(.good)))
        #expect(LogValue(type: .skinToday, raw: "bad") == nil)
    }

    @Test func wordsForSentencesAndButtons() {
        #expect(SkinToday.littleItchy.words == "a little itchy")
        #expect(SkinToday.littleItchy.title == "A little itchy")
        #expect(SkinToday.veryRough.title == "Very rough")
    }

    @Test func aDaytimeAnswerKeepsItsTime() {
        let at = TestTime.date(26, 16)
        #expect(SkinDay.timestamp(for: at, calendar: TestTime.calendar) == at)
        #expect(SkinDay.day(for: at, calendar: TestTime.calendar) == CareDay(year: 2026, month: 9, day: 26))
    }

    @Test(arguments: [(26, 20), (26, 23), (27, 2), (27, 6)])
    func aNightAnswerIsAboutTheDayThatJustEnded(day: Int, hour: Int) {
        let at = TestTime.date(day, hour)
        #expect(SkinDay.timestamp(for: at, calendar: TestTime.calendar) == TestTime.date(26, 18, 59))
        #expect(SkinDay.day(for: at, calendar: TestTime.calendar) == CareDay(year: 2026, month: 9, day: 26))
    }

    @Test func answeringAgainReplacesThatDaysAnswer() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 17))
        let first = try await harness.logs.log(.skinToday, value: .skin(.calm), child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 10)
        let second = try await harness.logs.log(.skinToday, value: .skin(.flaring), child: harness.child.id, source: .notification)

        let today = try await harness.logs.events(for: CareDay(year: 2026, month: 9, day: 26), child: harness.child.id)
        #expect(today.map(\.id) == [second.id])
        #expect(try await !harness.logs.isLive(first.id))
        let replaced = try harness.allStoredEvents().first { $0.id == first.id }
        #expect(replaced?.needsSync == true)
        #expect(replaced?.deletedAt != nil)
    }

    @Test func aNewDaysAnswerLeavesYesterdaysAlone() async throws {
        let harness = try await TestHarness(start: TestTime.date(25, 17))
        let yesterday = try await harness.logs.log(.skinToday, value: .skin(.calm), child: harness.child.id, source: .app)
        harness.clock.set(TestTime.date(26, 17))
        _ = try await harness.logs.log(.skinToday, value: .skin(.veryRough), child: harness.child.id, source: .app)
        #expect(try await harness.logs.isLive(yesterday.id))
    }

    @Test func anEveningAnswerLandsOnTodayNotTomorrow() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 21))
        let entry = try await harness.logs.log(.skinToday, value: .skin(.littleItchy), child: harness.child.id, source: .app)
        #expect(entry.timestamp == TestTime.date(26, 18, 59))
        let summary = DaySummary(
            day: CareDay(year: 2026, month: 9, day: 26),
            events: try await harness.logs.events(for: CareDay(year: 2026, month: 9, day: 26), child: harness.child.id),
            calendar: TestTime.calendar
        )
        #expect(summary.skinToday == .littleItchy)
    }

    @Test func undoAfterAReplaceLeavesTheDayUnanswered() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 17))
        _ = try await harness.logs.log(.skinToday, value: .skin(.calm), child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 1)
        let second = try await harness.logs.log(.skinToday, value: .skin(.flaring), child: harness.child.id, source: .app)
        let undone = try await harness.logs.undoLast()
        #expect(undone?.id == second.id)
        let today = try await harness.logs.events(for: CareDay(year: 2026, month: 9, day: 26), child: harness.child.id)
        #expect(today.isEmpty)
    }

    @Test func daySummaryTakesTheAnswer() {
        let day = CareDay(year: 2026, month: 9, day: 26)
        let events = [
            LogEntry(childID: nil, type: .flare, timestamp: TestTime.date(26, 10)),
            LogEntry(childID: nil, type: .skinToday, value: .skin(.flaring), timestamp: TestTime.date(26, 18)),
        ]
        #expect(DaySummary(day: day, events: events, calendar: TestTime.calendar).skinToday == .flaring)
        #expect(DaySummary(day: day, events: [events[0]], calendar: TestTime.calendar).skinToday == nil)
    }

    @Test func phrasesSayTheAnswer() {
        let phrases = LogPhrases(calendar: TestTime.calendar, locale: Locale(identifier: "en_US"))
        let entry = LogEntry(childID: nil, type: .skinToday, value: .skin(.veryRough), timestamp: TestTime.date(26, 18))
        #expect(phrases.name(for: entry) == "skin today: very rough")
    }
}
