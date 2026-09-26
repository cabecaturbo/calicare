import Core
import Foundation
import Testing

struct WidgetDataTests {
    private func source(_ harness: TestHarness, feedback: WidgetFeedbackStore = .isolated()) -> WidgetDataSource {
        WidgetDataSource(
            container: harness.container,
            setting: .isolated(),
            feedbackStore: feedback,
            calendar: TestTime.calendar
        )
    }

    @Test func countsTheCareDay() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let id = harness.child.id
        let logs = harness.logs
        try await logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 2))
        try await logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 8))
        try await logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(25, 12))
        try await logs.log(.bowelMovement, child: id, source: .widget)
        try await logs.log(.bowelMovement, value: .bowel(.hard), child: id, source: .intent)
        try await logs.log(.bowelMovement, value: .bowel(BowelMovement.none), child: id, source: .app)
        try await logs.log(.routineDone, child: id, source: .widget)

        let snapshot = try await source(harness).snapshot(for: harness.child, at: TestTime.date(26, 10))
        #expect(snapshot.child?.id == id)
        #expect(snapshot.itchCount == 2)
        #expect(snapshot.bowelMovementCount == 2)
        #expect(snapshot.routinesDone == 1)
        #expect(snapshot.lastItch == TestTime.date(26, 8))
    }

    @Test func noChildIsEmpty() async throws {
        let harness = try await TestHarness()
        #expect(try await source(harness).snapshot(for: nil, at: TestTime.date(26, 10)) == .empty)
    }

    @Test func daytimeShowsOnlyThisMorningsRating() async throws {
        let harness = try await TestHarness(start: TestTime.date(25, 7, 30))
        try await harness.logs.log(.nightRating, value: .night(.good), child: harness.child.id, source: .notification)
        let data = source(harness)

        // The 25th's rating isn't "last night" on the 26th.
        #expect(try await data.snapshot(for: harness.child, at: TestTime.date(26, 10)).lastNight == nil)

        harness.clock.set(TestTime.date(26, 7, 30))
        try await harness.logs.log(.nightRating, value: .night(.rough), child: harness.child.id, source: .notification)
        #expect(try await data.snapshot(for: harness.child, at: TestTime.date(26, 10)).lastNight == .rough)
    }

    @Test func eveningStillShowsLastNight() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 7, 30))
        try await harness.logs.log(.nightRating, value: .night(.okay), child: harness.child.id, source: .notification)
        #expect(try await source(harness).snapshot(for: harness.child, at: TestTime.date(26, 21)).lastNight == .okay)
    }

    @Test func overnightPrefersTonightsRating() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 7, 30))
        try await harness.logs.log(.nightRating, value: .night(.good), child: harness.child.id, source: .notification)
        harness.clock.set(TestTime.date(27, 1, 30))
        try await harness.logs.log(.nightRating, value: .night(.rough), child: harness.child.id, source: .widget)
        #expect(try await source(harness).snapshot(for: harness.child, at: TestTime.date(27, 2)).lastNight == .rough)
    }

    @Test func countsResetAtSevenPM() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 15))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget)
        let data = source(harness)
        #expect(try await data.snapshot(for: harness.child, at: TestTime.date(26, 18, 59)).itchCount == 1)
        #expect(try await data.snapshot(for: harness.child, at: TestTime.date(26, 19)).itchCount == 0)
    }

    @Test func childFollowsConfigurationThenCurrent() async throws {
        let harness = try await TestHarness()
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let data = source(harness)

        #expect(try await data.child(for: sibling.id)?.id == sibling.id)
        #expect(try await data.child(for: nil)?.id == harness.child.id)
        try await harness.children.deleteChild(sibling.id)
        #expect(try await data.child(for: sibling.id)?.id == harness.child.id)
    }

    // MARK: - "Logged" feedback

    @Test func feedbackShowsForAboutAMinute() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 15))
        let entry = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget)
        let store = WidgetFeedbackStore.isolated()
        store.latest = WidgetFeedback(logID: entry.id, childID: harness.child.id, title: "Itchy spell", loggedAt: entry.timestamp)
        let data = source(harness, feedback: store)

        #expect(try await data.feedback(for: harness.child, at: TestTime.date(26, 15)) != nil)
        #expect(try await data.feedback(for: harness.child, at: entry.timestamp.addingTimeInterval(59)) != nil)
        #expect(try await data.feedback(for: harness.child, at: entry.timestamp.addingTimeInterval(60)) == nil)
    }

    @Test func feedbackIsOnlyForThatChild() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 15))
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let entry = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget)
        let store = WidgetFeedbackStore.isolated()
        store.latest = WidgetFeedback(logID: entry.id, childID: harness.child.id, title: "Itchy spell", loggedAt: entry.timestamp)

        #expect(try await source(harness, feedback: store).feedback(for: sibling, at: TestTime.date(26, 15)) == nil)
    }

    @Test func feedbackEndsAfterUndo() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 15))
        let entry = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget)
        let store = WidgetFeedbackStore.isolated()
        store.latest = WidgetFeedback(logID: entry.id, childID: harness.child.id, title: "Itchy spell", loggedAt: entry.timestamp)
        try await harness.logs.undoLast(within: QuickLog.undoWindow)

        #expect(try await source(harness, feedback: store).feedback(for: harness.child, at: TestTime.date(26, 15)) == nil)
    }

    @Test func feedbackStoreRoundTrips() {
        let store = WidgetFeedbackStore.isolated()
        #expect(store.latest == nil)
        let feedback = WidgetFeedback(logID: UUID(), childID: UUID(), title: "Rough night", loggedAt: TestTime.date(26, 7))
        store.latest = feedback
        #expect(store.latest == feedback)
        store.latest = nil
        #expect(store.latest == nil)
    }
}

struct WidgetTimelineTests {
    private let calendar = TestTime.calendar

    @Test func afternoonRefreshesAtSevenAndEightPMAndSevenAM() {
        let dates = WidgetTimeline.dates(from: TestTime.date(26, 15, 5), feedback: nil, calendar: calendar)
        #expect(dates == [TestTime.date(26, 15, 5), TestTime.date(26, 19), TestTime.date(26, 20), TestTime.date(27, 7)])
    }

    @Test func lateEveningRollsToTomorrow() {
        let dates = WidgetTimeline.dates(from: TestTime.date(26, 22), feedback: nil, calendar: calendar)
        #expect(dates == [TestTime.date(26, 22), TestTime.date(27, 7), TestTime.date(27, 19), TestTime.date(27, 20)])
    }

    @Test func loggedStateEndsAfterAMinute() {
        let now = TestTime.date(26, 15, 5)
        let feedback = WidgetFeedback(logID: UUID(), childID: UUID(), title: "Itchy spell", loggedAt: now)
        let dates = WidgetTimeline.dates(from: now, feedback: feedback, calendar: calendar)
        #expect(dates.prefix(2) == [now, TestTime.date(26, 15, 6)])
    }

    @Test func expiredFeedbackAddsNothing() {
        let now = TestTime.date(26, 15, 5)
        let feedback = WidgetFeedback(logID: UUID(), childID: UUID(), title: "Itchy spell", loggedAt: TestTime.date(26, 15, 0))
        #expect(WidgetTimeline.dates(from: now, feedback: feedback, calendar: calendar).count == 4)
    }
}
