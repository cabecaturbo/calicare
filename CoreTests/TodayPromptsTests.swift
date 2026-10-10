import Core
import Foundation
import Testing

/// When Today asks the skin question, the first-run hint, and Undo after a swipe.
struct TodayPromptsTests {
    private let calendar = TestTime.calendar

    @Test func skinIsAskedFromFourUntilNight() {
        #expect(!TodayPrompts.asksSkin(at: TestTime.date(26, 9), answered: false, calendar: calendar))
        #expect(!TodayPrompts.asksSkin(at: TestTime.date(26, 15, 59), answered: false, calendar: calendar))
        #expect(TodayPrompts.asksSkin(at: TestTime.date(26, 16), answered: false, calendar: calendar))
        #expect(TodayPrompts.asksSkin(at: TestTime.date(26, 19, 30), answered: false, calendar: calendar))
        #expect(!TodayPrompts.asksSkin(at: TestTime.date(26, 20), answered: false, calendar: calendar))
        #expect(!TodayPrompts.asksSkin(at: TestTime.date(27, 3), answered: false, calendar: calendar))
    }

    @Test func anAnsweredDayIsNotAskedAgain() {
        #expect(!TodayPrompts.asksSkin(at: TestTime.date(26, 17), answered: true, calendar: calendar))
    }

    @Test func firstRunHintUntilTheFirstLog() {
        #expect(TodayPrompts.firstRunHint(hasEverLogged: false, isNight: false, asksSkin: true, childName: "Cal")
            == "Start here: one tap for today’s skin.")
        #expect(TodayPrompts.firstRunHint(hasEverLogged: false, isNight: false, asksSkin: false, childName: "Cal")
            == "Start here: tap Log whenever Cal itches.")
        #expect(TodayPrompts.firstRunHint(hasEverLogged: false, isNight: true, asksSkin: false, childName: "Cal")
            == "Tap Log whenever Cal wakes up with an itch.")
        #expect(TodayPrompts.firstRunHint(hasEverLogged: true, isNight: false, asksSkin: true, childName: "Cal") == nil)
    }

    @Test func restoreBringsBackADeletedLog() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let entry = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        try await harness.logs.delete(entry.id)
        harness.clock.advance(minutes: 1)

        let restored = try await harness.logs.restore(entry.id)
        #expect(restored?.id == entry.id)
        #expect(try await harness.logs.isLive(entry.id))
        #expect(try await harness.logs.restore(entry.id) == nil)
        let stored = try #require(try harness.allStoredEvents().first)
        #expect(stored.deletedAt == nil)
        #expect(stored.updatedAt == TestTime.date(26, 9, 1))
        #expect(stored.needsSync)
    }
}
