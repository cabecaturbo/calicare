import Core
import Foundation
import Testing

struct ReminderSchedulerTests {
    private struct Setup {
        let harness: TestHarness
        let center: FakeNotificationCenter
        let store: ReminderSettingsStore
        let scheduler: ReminderScheduler
    }

    private func setup(
        start: Date,
        authorized: Bool = true,
        turnOn kinds: [ReminderKind] = [.checkIn]
    ) async throws -> Setup {
        let harness = try await TestHarness(start: start)
        let center = FakeNotificationCenter(authorized: authorized)
        let store = ReminderSettingsStore.isolated()
        var settings = ReminderSettings()
        for kind in kinds { settings[kind].isOn = true }
        store.settings = settings
        let clock = harness.clock
        let scheduler = ReminderScheduler(
            center: center,
            container: harness.container,
            store: store,
            childSetting: .isolated(),
            calendar: TestTime.calendar,
            now: { clock.now }
        )
        return Setup(harness: harness, center: center, store: store, scheduler: scheduler)
    }

    private func checkInIDs(_ center: FakeNotificationCenter) -> [String] {
        center.pending.filter { $0.kind == .checkIn }.map(\.id)
    }

    @Test func schedulesCheckInsWhenAllowed() async throws {
        let setup = try await setup(start: TestTime.date(26, 6))
        try await setup.scheduler.refresh()
        #expect(checkInIDs(setup.center).count == ReminderPlanner.checkInDays)
        #expect(checkInIDs(setup.center).first == "calicare.checkIn.2026-09-26")
    }

    @Test func schedulesNothingWithoutPermission() async throws {
        let setup = try await setup(start: TestTime.date(26, 6), authorized: false)
        try await setup.scheduler.refresh()
        #expect(setup.center.pending.isEmpty)
    }

    @Test func aNightRatingSkipsThatMorningAndClearsItsNotification() async throws {
        let setup = try await setup(start: TestTime.date(26, 6))
        try await setup.scheduler.refresh()
        #expect(checkInIDs(setup.center).contains("calicare.checkIn.2026-09-26"))

        try await setup.harness.logs.log(.nightRating, value: .night(.rough), child: setup.harness.child.id, source: .widget)
        try await setup.scheduler.refresh()

        #expect(!checkInIDs(setup.center).contains("calicare.checkIn.2026-09-26"))
        #expect(checkInIDs(setup.center).first == "calicare.checkIn.2026-09-27")
        #expect(setup.center.removedDelivered.contains("calicare.checkIn.2026-09-26"))
    }

    @Test func aRatingAtElevenPMSkipsTomorrowsCheckIn() async throws {
        let setup = try await setup(start: TestTime.date(26, 23))
        try await setup.harness.logs.log(.nightRating, value: .night(.rough), child: setup.harness.child.id, source: .intent)
        try await setup.scheduler.refresh()

        #expect(!checkInIDs(setup.center).contains("calicare.checkIn.2026-09-27"))
        #expect(checkInIDs(setup.center).first == "calicare.checkIn.2026-09-28")
    }

    @Test func undoingTheRatingBringsTheCheckInBack() async throws {
        let setup = try await setup(start: TestTime.date(26, 6))
        try await setup.harness.logs.log(.nightRating, value: .night(.good), child: setup.harness.child.id, source: .widget)
        try await setup.scheduler.refresh()
        #expect(!checkInIDs(setup.center).contains("calicare.checkIn.2026-09-26"))

        try await setup.harness.logs.undoLast()
        try await setup.scheduler.refresh()
        #expect(checkInIDs(setup.center).contains("calicare.checkIn.2026-09-26"))
    }

    @Test func turningAReminderOffRemovesIt() async throws {
        let setup = try await setup(start: TestTime.date(26, 6), turnOn: [.checkIn, .eveningRoutine])
        try await setup.scheduler.refresh()
        #expect(setup.center.pending.contains { $0.kind == .eveningRoutine })

        var settings = setup.store.settings
        settings.checkIn.isOn = false
        settings.eveningRoutine.isOn = false
        setup.store.settings = settings
        try await setup.scheduler.refresh()
        #expect(setup.center.pending.isEmpty)
    }

    @Test func aSnoozeSurvivesRefreshUntilItsReminderIsTurnedOff() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 30), turnOn: [.morningRoutine])
        let payload = ReminderPayload(kind: .morningRoutine, childID: setup.harness.child.id, fireDate: nil)
        try await setup.scheduler.snooze(payload)
        try await setup.scheduler.refresh()
        #expect(setup.center.pending.contains { $0.id == "calicare.snooze.morningRoutine" })

        var settings = setup.store.settings
        settings.morningRoutine.isOn = false
        setup.store.settings = settings
        try await setup.scheduler.refresh()
        #expect(setup.center.pending.isEmpty)
    }

    @Test func settingsAreSavedAndRead() {
        let store = ReminderSettingsStore.isolated()
        #expect(store.settings == ReminderSettings())
        #expect(!store.hasOfferedReminders)

        var settings = ReminderSettings()
        settings.turnAllOn()
        settings.eveningRoutine.hour = 20
        settings.eveningRoutine.minute = 15
        store.settings = settings
        store.hasOfferedReminders = true

        #expect(store.settings == settings)
        #expect(store.hasOfferedReminders)
    }
}
