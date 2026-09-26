import Core
import Foundation
import Testing

struct LogStoreTests {
    @Test func logSavesEveryField() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let entry = try await harness.logs.log(
            .mood, value: .mood(.cranky), child: harness.child.id,
            source: .widget, note: "  after daycare ", loggedBy: "Sam"
        )

        #expect(entry.type == .mood)
        #expect(entry.value == .mood(.cranky))
        #expect(entry.note == "after daycare")
        #expect(entry.source == .widget)
        #expect(entry.loggedBy == "Sam")
        #expect(entry.timestamp == TestTime.date(26, 9))
        #expect(entry.childID == harness.child.id)

        let stored = try #require(try harness.allStoredEvents().first)
        #expect(stored.id == entry.id)
        #expect(stored.needsSync)
        #expect(stored.deletedAt == nil)
        #expect(stored.createdAt == TestTime.date(26, 9))
        #expect(stored.updatedAt == stored.createdAt)
        #expect(stored.entrySource == .widget)
        #expect(stored.childID == harness.child.id)
    }

    @Test func backdatedLogKeepsItsTimestamp() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 8))
        let entry = try await harness.logs.log(
            .itchEpisode, child: harness.child.id, source: .app, at: TestTime.date(26, 3)
        )
        #expect(entry.timestamp == TestTime.date(26, 3))
    }

    @Test func rejectsMismatchedValues() async throws {
        let harness = try await TestHarness()
        let id = harness.child.id
        await #expect(throws: LogStoreError.invalidValue) {
            try await harness.logs.log(.nightRating, value: .mood(.great), child: id, source: .app)
        }
        await #expect(throws: LogStoreError.invalidValue) {
            try await harness.logs.log(.nightRating, child: id, source: .app)
        }
        await #expect(throws: LogStoreError.invalidValue) {
            try await harness.logs.log(.itchEpisode, value: .night(.rough), child: id, source: .app)
        }
        await #expect(throws: LogStoreError.emptyNote) {
            try await harness.logs.log(.note, child: id, source: .app, note: "   ")
        }
        #expect(try harness.allStoredEvents().isEmpty)
    }

    @Test func rejectsUnknownChild() async throws {
        let harness = try await TestHarness()
        await #expect(throws: LogStoreError.childNotFound) {
            try await harness.logs.log(.flare, child: UUID(), source: .intent)
        }
    }

    @Test func undoSoftDeletesNewestFirst() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let first = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 5)
        let second = try await harness.logs.log(.routineDone, child: harness.child.id, source: .widget)
        harness.clock.advance(minutes: 1)

        #expect(try await harness.logs.undoLast()?.id == second.id)
        #expect(try await harness.logs.undoLast()?.id == first.id)
        #expect(try await harness.logs.undoLast() == nil)

        let stored = try harness.allStoredEvents()
        #expect(stored.count == 2)
        for event in stored {
            #expect(event.deletedAt == TestTime.date(26, 9, 6))
            #expect(event.updatedAt == TestTime.date(26, 9, 6))
            #expect(event.needsSync)
        }
    }

    @Test func undoUsesCreationOrderNotTimestamp() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let newer = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 1)
        let backdated = try await harness.logs.log(
            .itchEpisode, child: harness.child.id, source: .app, at: TestTime.date(26, 2)
        )
        #expect(newer.timestamp > backdated.timestamp)
        #expect(try await harness.logs.undoLast()?.id == backdated.id)
    }

    @Test func undoOnEmptyStoreReturnsNil() async throws {
        let harness = try await TestHarness()
        #expect(try await harness.logs.undoLast() == nil)
    }

    @Test func softDeletedLogsAreHiddenFromQueries() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 1)
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app)
        try await harness.logs.undoLast()

        let day = CareDay(year: 2026, month: 9, day: 26)
        #expect(try await harness.logs.events(for: day, child: harness.child.id).count == 1)
        #expect(try await harness.logs.todaySummary(child: harness.child.id).itchEpisodes == 1)
        #expect(try harness.allStoredEvents().count == 2)
    }
}
