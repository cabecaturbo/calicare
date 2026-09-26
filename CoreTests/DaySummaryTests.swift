import Core
import Foundation
import Testing

struct DaySummaryTests {
    private let sept26 = CareDay(year: 2026, month: 9, day: 26)

    @Test func itchAtTwoAMCountsTowardThatMorningsNight() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .watch)

        let summary = try await harness.logs.todaySummary(child: harness.child.id)
        #expect(summary.day == sept26)
        #expect(summary.nightItchEpisodes == 1)
        #expect(summary.daytimeItchEpisodes == 0)

        let previous = try await harness.logs.events(for: sept26.adding(days: -1, calendar: TestTime.calendar), child: harness.child.id)
        #expect(previous.isEmpty)
    }

    @Test func eveningBeforeLandsInTodaysNight() async throws {
        let harness = try await TestHarness(start: TestTime.date(25, 22))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget)
        harness.clock.set(TestTime.date(26, 7, 30))
        try await harness.logs.log(.nightRating, value: .night(.rough), child: harness.child.id, source: .notification)

        let summary = try await harness.logs.todaySummary(child: harness.child.id)
        #expect(summary.day == sept26)
        #expect(summary.nightItchEpisodes == 1)
        #expect(summary.nightRating == .rough)
        #expect(summary.totalEvents == 2)
    }

    @Test func todayRollsForwardAtSevenPM() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 18, 59))
        try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.set(TestTime.date(26, 20))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app)

        let summary = try await harness.logs.todaySummary(child: harness.child.id)
        #expect(summary.day == CareDay(year: 2026, month: 9, day: 27))
        #expect(summary.flares == 0)
        #expect(summary.nightItchEpisodes == 1)
    }

    @Test func countsAndLatestValues() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 8))
        let id = harness.child.id
        let logs = harness.logs
        try await logs.log(.nightRating, value: .night(.okay), child: id, source: .notification)
        try await logs.log(.nightRating, value: .night(.good), child: id, source: .app, at: TestTime.date(26, 8, 5))
        try await logs.log(.mood, value: .mood(.cranky), child: id, source: .widget, at: TestTime.date(26, 9))
        try await logs.log(.mood, value: .mood(.great), child: id, source: .widget, at: TestTime.date(26, 15))
        try await logs.log(.bowelMovement, value: .bowel(.hard), child: id, source: .intent, at: TestTime.date(26, 10))
        try await logs.log(.bowelMovement, value: .bowel(.good), child: id, source: .intent, at: TestTime.date(26, 16))
        try await logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 11))
        try await logs.log(.flare, child: id, source: .app, at: TestTime.date(26, 12))
        try await logs.log(.routineDone, child: id, source: .widget, at: TestTime.date(26, 13))
        try await logs.log(.note, child: id, source: .app, note: "New lotion", at: TestTime.date(26, 14))

        let summary = try await logs.todaySummary(child: id)
        #expect(summary.nightRating == .good)
        #expect(summary.mood == .great)
        #expect(summary.bowelMovements == [.hard, .good])
        #expect(summary.daytimeItchEpisodes == 1)
        #expect(summary.nightItchEpisodes == 0)
        #expect(summary.flares == 1)
        #expect(summary.routinesDone == 1)
        #expect(summary.notes == 1)
        #expect(summary.totalEvents == 10)
    }

    @Test func childrenAreKeptSeparate() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        try await harness.logs.log(.itchEpisode, child: sibling.id, source: .app)

        #expect(try await harness.logs.todaySummary(child: harness.child.id).flares == 1)
        #expect(try await harness.logs.todaySummary(child: harness.child.id).itchEpisodes == 0)
        #expect(try await harness.logs.events(for: sept26, child: sibling.id).map(\.type) == [.itchEpisode])
    }

    @Test func emptyDayIsAllZero() {
        let summary = DaySummary(day: sept26, events: [], calendar: TestTime.calendar)
        #expect(summary.totalEvents == 0)
        #expect(summary.nightRating == nil)
        #expect(summary.mood == nil)
        #expect(summary.bowelMovements.isEmpty)
    }

    @Test func pureSummaryIgnoresEventsOutsideTheDay() {
        let events = [
            LogEntry(childID: nil, type: .flare, timestamp: TestTime.date(25, 18, 59)),
            LogEntry(childID: nil, type: .flare, timestamp: TestTime.date(25, 19)),
            LogEntry(childID: nil, type: .itchEpisode, timestamp: TestTime.date(26, 7)),
            LogEntry(childID: nil, type: .flare, timestamp: TestTime.date(26, 19)),
        ]
        let summary = DaySummary(day: sept26, events: events, calendar: TestTime.calendar)
        #expect(summary.flares == 1)
        #expect(summary.daytimeItchEpisodes == 1)
        #expect(summary.nightItchEpisodes == 0)
    }
}
