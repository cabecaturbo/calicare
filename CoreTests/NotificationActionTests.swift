import Core
import Foundation
import Testing

struct NotificationActionTests {
    private struct Setup {
        let harness: TestHarness
        let center: FakeNotificationCenter
        let handler: NotificationActionHandler
    }

    private func setup(start: Date, turnOn kinds: [ReminderKind] = []) async throws -> Setup {
        let harness = try await TestHarness(start: start)
        let center = FakeNotificationCenter()
        let store = ReminderSettingsStore.isolated()
        var settings = ReminderSettings()
        for kind in kinds { settings[kind].isOn = true }
        store.settings = settings
        let childSetting = CurrentChildSetting.isolated()
        let clock = harness.clock
        let quickLog = QuickLog(
            container: harness.container,
            setting: childSetting,
            calendar: TestTime.calendar,
            locale: Locale(identifier: "en_US"),
            now: { clock.now }
        )
        let scheduler = ReminderScheduler(
            center: center,
            container: harness.container,
            store: store,
            childSetting: childSetting,
            calendar: TestTime.calendar,
            now: { clock.now }
        )
        let handler = NotificationActionHandler(
            quickLog: quickLog,
            scheduler: scheduler,
            calendar: TestTime.calendar,
            now: { clock.now }
        )
        return Setup(harness: harness, center: center, handler: handler)
    }

    private func loggedEntry(_ outcome: NotificationActionHandler.Outcome) throws -> LogEntry {
        guard case .logged(let entry) = outcome else {
            Issue.record("Expected a log, got \(outcome)")
            throw CancellationError()
        }
        return entry
    }

    static let ratings: [(ReminderAction, NightRating)] = [(.good, .good), (.okay, .okay), (.rough, .rough)]

    @Test(arguments: ratings)
    func checkInButtonsLogTheNight(action: ReminderAction, rating: NightRating) async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let payload = ReminderPayload(kind: .checkIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 7))

        let entry = try loggedEntry(try await setup.handler.handle(actionIdentifier: action.identifier, payload: payload))

        #expect(entry.type == .nightRating)
        #expect(entry.value == .night(rating))
        #expect(entry.source == .notification)
        #expect(entry.childID == setup.harness.child.id)
        #expect(entry.timestamp == TestTime.date(26, 7, 5))
        #expect(try setup.harness.allStoredEvents().map(\.entrySource) == [.notification])
    }

    @Test func usesTheCurrentChildWhenNoneIsNamed() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let payload = ReminderPayload(kind: .checkIn, childID: nil, fireDate: TestTime.date(26, 7))
        let entry = try loggedEntry(try await setup.handler.handle(actionIdentifier: ReminderAction.good.identifier, payload: payload))
        #expect(entry.childID == setup.harness.child.id)
    }

    @Test func fallsBackToTheCurrentChildWhenTheNamedOneWasRemoved() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let sibling = try await setup.harness.children.addChild(name: "Leo", colorTag: "clay")
        try await setup.harness.children.deleteChild(sibling.id)
        let payload = ReminderPayload(kind: .checkIn, childID: sibling.id, fireDate: TestTime.date(26, 7))

        let entry = try loggedEntry(try await setup.handler.handle(actionIdentifier: ReminderAction.okay.identifier, payload: payload))
        #expect(entry.childID == setup.harness.child.id)
    }

    @Test(arguments: [(ReminderKind.morningRoutine, RoutineTime.morning), (.eveningRoutine, .evening)])
    func doneLogsTheRoutine(kind: ReminderKind, time: RoutineTime) async throws {
        let setup = try await setup(start: TestTime.date(26, 19, 10))
        let payload = ReminderPayload(kind: kind, childID: setup.harness.child.id, fireDate: nil)

        let entry = try loggedEntry(try await setup.handler.handle(actionIdentifier: ReminderAction.done.identifier, payload: payload))

        #expect(entry.type == .routineDone)
        #expect(entry.value == .routine(time))
        #expect(entry.source == .notification)
    }

    @Test func snoozeLogsNothingAndComesBackLater() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 30), turnOn: [.morningRoutine])
        let payload = ReminderPayload(kind: .morningRoutine, childID: setup.harness.child.id, fireDate: nil)

        let outcome = try await setup.handler.handle(actionIdentifier: ReminderAction.snooze.identifier, payload: payload)

        #expect(outcome == .snoozed)
        #expect(try setup.harness.allStoredEvents().isEmpty)
        let snoozed = try #require(setup.center.pending.first { $0.id == "calicare.snooze.morningRoutine" })
        #expect(snoozed.trigger == .after(30 * 60))
        #expect(snoozed.payload == payload)
    }

    @Test(arguments: [
        "com.apple.UNNotificationDefaultActionIdentifier",
        "com.apple.UNNotificationDismissActionIdentifier",
        ReminderAction.done.identifier,
    ])
    func otherResponsesOnACheckInDoNothing(actionIdentifier: String) async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let payload = ReminderPayload(kind: .checkIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 7))

        let outcome = try await setup.handler.handle(actionIdentifier: actionIdentifier, payload: payload)

        #expect(outcome == .ignored)
        #expect(try setup.harness.allStoredEvents().isEmpty)
        #expect(setup.center.pending.isEmpty)
    }

    @Test func notificationsThatArentOursDoNothing() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let outcome = try await setup.handler.handle(actionIdentifier: ReminderAction.good.identifier, payload: nil)
        #expect(outcome == .ignored)
    }

    @Test func aLateAnswerLandsOnTheRightNight() async throws {
        let setup = try await setup(start: TestTime.date(27, 9))
        let payload = ReminderPayload(kind: .checkIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 7))

        let entry = try loggedEntry(try await setup.handler.handle(actionIdentifier: ReminderAction.rough.identifier, payload: payload))

        #expect(entry.timestamp == TestTime.date(26, 7))
    }

    @Test func answeringClearsThatMorningsCheckIn() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5), turnOn: [.checkIn])
        let payload = ReminderPayload(kind: .checkIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 7))

        _ = try await setup.handler.handle(actionIdentifier: ReminderAction.good.identifier, payload: payload)

        #expect(setup.center.removedDelivered.contains("calicare.checkIn.2026-09-26"))
        #expect(setup.center.pending.filter { $0.kind == .checkIn }.count == ReminderPlanner.checkInDays)
    }
}
