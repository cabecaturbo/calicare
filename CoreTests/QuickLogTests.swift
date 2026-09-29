import Core
import Foundation
import Testing

struct QuickLogTests {
    private func quickLog(_ harness: TestHarness, setting: CurrentChildSetting = .isolated()) -> QuickLog {
        let clock = harness.clock
        return QuickLog(
            container: harness.container,
            setting: setting,
            calendar: TestTime.calendar,
            locale: Locale(identifier: "en_US"),
            now: { clock.now }
        )
    }

    @Test func logsForTheCurrentChildFromAnIntent() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2, 14))
        let text = try await quickLog(harness).log(.itchEpisode)

        #expect(text == "Logged itchy wake-up for Ada, 2:14 AM.")
        let stored = try #require(try harness.allStoredEvents().first)
        #expect(stored.entrySource == .intent)
        #expect(stored.childID == harness.child.id)
    }

    @Test func usesTheSavedCurrentChild() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 7, 30))
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let setting = CurrentChildSetting.isolated()
        setting.childID = sibling.id

        let text = try await quickLog(harness, setting: setting).log(.nightRating, value: .night(.rough))
        #expect(text == "Logged rough night for Leo, 7:30 AM.")
        #expect(try harness.allStoredEvents().first?.childID == sibling.id)
    }

    @Test func explicitChildWins() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 15))
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")

        let text = try await quickLog(harness).log(.bowelMovement, value: .bowel(.hard), childID: sibling.id)
        #expect(text == "Logged hard bowel movement for Leo, 3:00 PM.")
        #expect(try harness.allStoredEvents().first?.childID == sibling.id)
    }

    @Test func noChildrenYet() async throws {
        let harness = try await TestHarness()
        try await harness.children.deleteChild(harness.child.id)
        await #expect(throws: QuickLogError.noChild) {
            try await quickLog(harness).log(.itchEpisode)
        }
    }

    @Test func removedChild() async throws {
        let harness = try await TestHarness()
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        try await harness.children.deleteChild(sibling.id)
        await #expect(throws: QuickLogError.childNotFound) {
            try await quickLog(harness).log(.itchEpisode, childID: sibling.id)
        }
        #expect(try harness.allStoredEvents().isEmpty)
    }

    @Test func undoSaysWhatItRemoved() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2, 14))
        let quick = quickLog(harness)
        try await quick.log(.itchEpisode)
        harness.clock.advance(minutes: 3)

        #expect(try await quick.undoRecent() == "Removed itchy wake-up, 2:14 AM.")
        #expect(try harness.allStoredEvents().first?.deletedAt != nil)
    }

    @Test func undoIsKindWhenNothingIsRecent() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 2, 14))
        let quick = quickLog(harness)
        try await quick.log(.itchEpisode)
        harness.clock.advance(minutes: 11)

        #expect(try await quick.undoRecent() == LogPhrases.nothingToUndo)
        #expect(try harness.allStoredEvents().first?.deletedAt == nil)
    }

    @Test func undoOnAnEmptyStore() async throws {
        let harness = try await TestHarness()
        #expect(try await quickLog(harness).undoRecent() == LogPhrases.nothingToUndo)
    }

    /// "Get Weekly Card" and "Get Care Log" pick the child the same way logging does.
    @Test func reportIntentsPickTheChosenOrCurrentChild() async throws {
        let harness = try await TestHarness()
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let setting = CurrentChildSetting.isolated()
        setting.childID = sibling.id
        let quick = quickLog(harness, setting: setting)

        #expect(try await quick.child(nil).id == sibling.id)
        #expect(try await quick.child(harness.child.id).id == harness.child.id)
        await #expect(throws: QuickLogError.childNotFound) { try await quick.child(UUID()) }
    }
}
