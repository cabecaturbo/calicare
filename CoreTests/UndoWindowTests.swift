import Core
import Foundation
import Testing

struct UndoWindowTests {
    private let window = QuickLog.undoWindow

    @Test func windowIsTenMinutes() {
        #expect(window == 600)
    }

    @Test(arguments: [0, 60, 599, 600])
    func undoesTheNewestLogInsideTheWindow(secondsLater: Int) async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2, 14))
        let entry = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .intent)
        harness.clock.advance(seconds: secondsLater)

        #expect(try await harness.logs.undoLast(within: window)?.id == entry.id)
        #expect(try harness.allStoredEvents().first?.deletedAt != nil)
    }

    @Test(arguments: [601, 3600])
    func leavesOlderLogsAlone(secondsLater: Int) async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2, 14))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .intent)
        harness.clock.advance(seconds: secondsLater)

        #expect(try await harness.logs.undoLast(within: window) == nil)
        #expect(try harness.allStoredEvents().first?.deletedAt == nil)
    }

    @Test func neverReachesPastTheNewestLog() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let older = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 5)
        let newer = try await harness.logs.log(.routineDone, child: harness.child.id, source: .widget)
        harness.clock.advance(minutes: 7)

        #expect(try await harness.logs.undoLast(within: window)?.id == newer.id)
        #expect(try await harness.logs.undoLast(within: window) == nil)

        let live = try harness.allStoredEvents().filter { $0.deletedAt == nil }
        #expect(live.map(\.id) == [older.id])
    }

    @Test func backdatedLogCanBeUndoneRightAway() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let backdated = try await harness.logs.log(
            .itchEpisode, child: harness.child.id, source: .app, at: TestTime.date(26, 2)
        )
        harness.clock.advance(minutes: 1)
        #expect(try await harness.logs.undoLast(within: window)?.id == backdated.id)
    }

    @Test func undoWithoutWindowStillReachesOlderLogs() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let entry = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 60)
        #expect(try await harness.logs.undoLast()?.id == entry.id)
    }
}
