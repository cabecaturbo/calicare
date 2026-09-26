import Core
import Foundation
import Testing

struct LogEditingTests {
    @Test func updateChangesValueNoteAndTime() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let entry = try await harness.logs.log(.nightRating, value: .night(.okay), child: harness.child.id, source: .widget)
        harness.clock.advance(minutes: 5)

        let updated = try await harness.logs.update(
            entry.id, value: .night(.rough), note: "  up at 3 ", timestamp: TestTime.date(26, 8)
        )

        #expect(updated.value == .night(.rough))
        #expect(updated.note == "up at 3")
        #expect(updated.timestamp == TestTime.date(26, 8))
        #expect(updated.source == .widget)
        let stored = try #require(try harness.allStoredEvents().first)
        #expect(stored.updatedAt == TestTime.date(26, 9, 5))
        #expect(stored.createdAt == TestTime.date(26, 9))
        #expect(stored.needsSync)
    }

    @Test func updateValidatesLikeLogging() async throws {
        let harness = try await TestHarness()
        let night = try await harness.logs.log(.nightRating, value: .night(.good), child: harness.child.id, source: .app)
        let note = try await harness.logs.log(.note, child: harness.child.id, source: .app, note: "Oat bath")

        await #expect(throws: LogStoreError.invalidValue) {
            try await harness.logs.update(night.id, value: .mood(.great), note: nil, timestamp: night.timestamp)
        }
        await #expect(throws: LogStoreError.emptyNote) {
            try await harness.logs.update(note.id, value: nil, note: "  ", timestamp: note.timestamp)
        }
        await #expect(throws: LogStoreError.logNotFound) {
            try await harness.logs.update(UUID(), value: nil, note: nil, timestamp: .now)
        }
    }

    @Test func deleteIsSoftAndOnlyOnce() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let first = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 1)
        let second = try await harness.logs.log(.flare, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 1)

        // Deletes the one asked for, not the newest.
        let deleted = try await harness.logs.delete(first.id)
        #expect(deleted?.id == first.id)
        #expect(try await harness.logs.delete(first.id) == nil)

        let live = try await harness.logs.events(for: CareDay(year: 2026, month: 9, day: 26), child: harness.child.id)
        #expect(live.map(\.id) == [second.id])

        let stored = try #require(try harness.allStoredEvents().first(where: { $0.id == first.id }))
        #expect(stored.deletedAt == TestTime.date(26, 9, 2))
        #expect(stored.updatedAt == TestTime.date(26, 9, 2))
        #expect(stored.needsSync)

        await #expect(throws: LogStoreError.logNotFound) {
            try await harness.logs.update(first.id, value: nil, note: nil, timestamp: first.timestamp)
        }
    }

    @Test func rangeCoversWholeCareDays() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 12))
        let id = harness.child.id
        // Sept 20 7 PM belongs to care day Sept 21, the first day of the range.
        let inFirst = try await harness.logs.log(.itchEpisode, child: id, source: .app, at: TestTime.date(20, 19))
        _ = try await harness.logs.log(.itchEpisode, child: id, source: .app, at: TestTime.date(20, 18))
        let inLast = try await harness.logs.log(.itchEpisode, child: id, source: .app, at: TestTime.date(26, 18))
        _ = try await harness.logs.log(.itchEpisode, child: id, source: .app, at: TestTime.date(26, 19))

        let first = CareDay(year: 2026, month: 9, day: 21)
        let last = CareDay(year: 2026, month: 9, day: 26)
        let events = try await harness.logs.events(from: first, through: last, child: id)
        #expect(events.map(\.id) == [inFirst.id, inLast.id])
    }
}

struct ChildStoreTests {
    @Test func nameIsTrimmedAndRequired() async throws {
        let harness = try await TestHarness()
        let child = try await harness.children.addChild(name: "  Leo ", colorTag: "clay")
        #expect(child.name == "Leo")
        await #expect(throws: ChildStoreError.emptyName) {
            try await harness.children.addChild(name: "   ", colorTag: "sage")
        }
    }

    @Test func colorTagFallsBackToSage() {
        #expect(ChildColor(tag: "clay") == .clay)
        #expect(ChildColor(tag: "purple") == .sage)
        #expect(ChildColor(tag: nil) == .sage)
    }

    @Test func routineGuessFollowsTimeOfDay() {
        #expect(RoutineTime.likely(at: TestTime.date(26, 7), calendar: TestTime.calendar) == .morning)
        #expect(RoutineTime.likely(at: TestTime.date(26, 13, 59), calendar: TestTime.calendar) == .morning)
        #expect(RoutineTime.likely(at: TestTime.date(26, 14), calendar: TestTime.calendar) == .evening)
        #expect(RoutineTime.likely(at: TestTime.date(26, 21), calendar: TestTime.calendar) == .evening)
    }
}
