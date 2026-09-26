import Core
import Foundation
import Testing

struct WidgetLoggingTests {
    @Test func bowelMovementNeedsNoKind() async throws {
        #expect(LogType.bowelMovement.accepts(nil))
        #expect(!LogType.bowelMovement.accepts(.night(.good)))
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let entry = try await harness.logs.log(.bowelMovement, child: harness.child.id, source: .widget)
        #expect(entry.value == nil)
    }

    @Test func noneIsNotCountedAsABowelMovement() {
        let day = CareDay(year: 2026, month: 9, day: 26)
        let events = [
            LogEntry(childID: nil, type: .bowelMovement, timestamp: TestTime.date(26, 9)),
            LogEntry(childID: nil, type: .bowelMovement, value: .bowel(.loose), timestamp: TestTime.date(26, 10)),
            LogEntry(childID: nil, type: .bowelMovement, value: .bowel(BowelMovement.none), timestamp: TestTime.date(26, 11)),
        ]
        let summary = DaySummary(day: day, events: events, calendar: TestTime.calendar)
        #expect(summary.bowelMovementCount == 2)
        #expect(summary.bowelMovements == [.loose, BowelMovement.none])
    }

    @Test(arguments: WidgetAction.allCases)
    func widgetActionsAreValidLogs(action: WidgetAction) {
        #expect(action.logType.accepts(action.value))
    }

    @Test func widgetTapsAreTaggedWidget() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 7, 30))
        let clock = harness.clock
        let quick = QuickLog(
            container: harness.container,
            setting: .isolated(),
            calendar: TestTime.calendar,
            now: { clock.now }
        )
        let saved = try await quick.record(
            WidgetAction.roughNight.logType, value: WidgetAction.roughNight.value, source: .widget
        )
        #expect(saved.entry.source == .widget)
        #expect(saved.entry.value == .night(.rough))
        #expect(saved.child.id == harness.child.id)
        #expect(try harness.allStoredEvents().first?.entrySource == .widget)
    }

    @Test func latestAndLiveAndRecent() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let id = harness.child.id
        let early = try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 2))
        harness.clock.advance(minutes: 1)
        let flare = try await harness.logs.log(.flare, child: id, source: .app)
        harness.clock.advance(minutes: 1)
        let backdated = try await harness.logs.log(.itchEpisode, child: id, source: .app, at: TestTime.date(26, 1))

        #expect(try await harness.logs.latest(.itchEpisode, child: id)?.id == early.id)
        #expect(try await harness.logs.recent(limit: 2).map(\.id) == [backdated.id, flare.id])

        #expect(try await harness.logs.isLive(backdated.id))
        try await harness.logs.undoLast()
        #expect(try await harness.logs.isLive(backdated.id) == false)
        #expect(try await harness.logs.isLive(UUID()) == false)
    }

    @Test func titleIsCapitalized() {
        let phrases = LogPhrases(calendar: TestTime.calendar, locale: Locale(identifier: "en_US"))
        let entry = LogEntry(childID: nil, type: .itchEpisode, timestamp: TestTime.date(26, 2))
        #expect(phrases.title(for: entry) == "Itchy wake-up")
    }
}
