import Core
import Foundation
import Testing

/// The evening skin check-in: planning, scheduling, and its four buttons.
struct SkinCheckInTests {
    private let planner = ReminderPlanner(calendar: TestTime.calendar)

    private var skinOn: ReminderSettings {
        var settings = ReminderSettings()
        settings.skinCheckIn.isOn = true
        return settings
    }

    // MARK: - Planning

    @Test func fourteenEveningQuestionsAtSixThirty() async throws {
        let harness = try await TestHarness()
        let plan = planner.plan(settings: skinOn, child: harness.child, ratedDays: [], now: TestTime.date(26, 9))
            .filter { $0.kind == .skinCheckIn }

        #expect(plan.count == ReminderPlanner.checkInDays)
        #expect(plan.first?.fireDate == TestTime.date(26, 18, 30))
        #expect(plan.first?.id == "calicare.skin.2026-09-26")
        #expect(plan.first?.title == "How was Ada's skin today?")
        #expect(plan.first?.body == "One tap is enough.")
        #expect(plan.first?.payload == ReminderPayload(kind: .skinCheckIn, childID: harness.child.id, fireDate: TestTime.date(26, 18, 30)))
    }

    @Test func skipsADayAlreadyAnswered() async throws {
        let harness = try await TestHarness()
        let today = CareDay(year: 2026, month: 9, day: 26)
        let plan = planner.plan(settings: skinOn, child: harness.child, ratedDays: [], skinDays: [today], now: TestTime.date(26, 9))
            .filter { $0.kind == .skinCheckIn }
        #expect(plan.first?.fireDate == TestTime.date(27, 18, 30))
    }

    @Test func aLateTimeStillAsksAboutThatDay() async throws {
        let harness = try await TestHarness()
        var settings = skinOn
        settings.skinCheckIn.hour = 20
        settings.skinCheckIn.minute = 0
        let plan = planner.plan(settings: settings, child: harness.child, ratedDays: [], now: TestTime.date(26, 9))
        #expect(plan.first?.id == "calicare.skin.2026-09-26")
        #expect(plan.first?.fireDate == TestTime.date(26, 20))
    }

    @Test func savedSettingsFromBeforeTheSkinCheckInStillLoad() throws {
        let old = #"{"checkIn":{"isOn":true,"hour":6,"minute":45},"morningRoutine":{"isOn":false,"hour":7,"minute":30},"eveningRoutine":{"isOn":true,"hour":20,"minute":0}}"#
        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(old.utf8))
        #expect(settings.checkIn == ReminderSlot(isOn: true, hour: 6, minute: 45))
        #expect(settings.eveningRoutine == ReminderSlot(isOn: true, hour: 20, minute: 0))
        #expect(settings.skinCheckIn == ReminderSlot(isOn: false, hour: 18, minute: 30))
    }

    @Test func settingsListsItAfterTheMorningCheckIn() {
        #expect(ReminderKind.allCases == [.checkIn, .skinCheckIn, .morningRoutine, .eveningRoutine])
        #expect(ReminderCopy.settingsTitle(.skinCheckIn) == "Evening skin check-in")
    }

    // MARK: - Scheduling and buttons

    private struct Setup {
        let harness: TestHarness
        let center: FakeNotificationCenter
        let scheduler: ReminderScheduler
        let handler: NotificationActionHandler
    }

    private func setup(start: Date) async throws -> Setup {
        let harness = try await TestHarness(start: start)
        let center = FakeNotificationCenter()
        let store = ReminderSettingsStore.isolated()
        store.settings = skinOn
        let childSetting = CurrentChildSetting.isolated()
        let clock = harness.clock
        let scheduler = ReminderScheduler(
            center: center, container: harness.container, store: store, childSetting: childSetting,
            calendar: TestTime.calendar, now: { clock.now }
        )
        let quickLog = QuickLog(
            container: harness.container, setting: childSetting, calendar: TestTime.calendar,
            locale: Locale(identifier: "en_US"), now: { clock.now }
        )
        let handler = NotificationActionHandler(quickLog: quickLog, scheduler: scheduler, calendar: TestTime.calendar, now: { clock.now })
        return Setup(harness: harness, center: center, scheduler: scheduler, handler: handler)
    }

    private func skinIDs(_ center: FakeNotificationCenter) -> [String] {
        center.pending.filter { $0.kind == .skinCheckIn }.map(\.id)
    }

    static let answers: [(ReminderAction, SkinToday)] = [
        (.calm, .calm), (.littleItchy, .littleItchy), (.flaring, .flaring), (.veryRough, .veryRough),
    ]

    @Test(arguments: answers)
    func eachButtonLogsItsAnswer(action: ReminderAction, answer: SkinToday) async throws {
        let setup = try await setup(start: TestTime.date(26, 18, 35))
        let payload = ReminderPayload(kind: .skinCheckIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 18, 30))
        let outcome = try await setup.handler.handle(actionIdentifier: action.identifier, payload: payload)
        guard case .logged(let entry) = outcome else {
            Issue.record("Expected a log, got \(outcome)")
            return
        }
        #expect(entry.type == .skinToday)
        #expect(entry.value == .skin(answer))
        #expect(entry.source == .notification)
        #expect(entry.timestamp == TestTime.date(26, 18, 35))
    }

    @Test func buttonTitlesMatchTheAnswers() {
        #expect([ReminderAction.calm, .littleItchy, .flaring, .veryRough].map(\.title) == ["Calm", "A little itchy", "Flaring", "Very rough"])
    }

    @Test func aTapTheNextMorningCountsForTheDayItAsked() async throws {
        let setup = try await setup(start: TestTime.date(27, 8))
        let payload = ReminderPayload(kind: .skinCheckIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 18, 30))
        let outcome = try await setup.handler.handle(actionIdentifier: ReminderAction.flaring.identifier, payload: payload)
        guard case .logged(let entry) = outcome else {
            Issue.record("Expected a log, got \(outcome)")
            return
        }
        #expect(entry.timestamp == TestTime.date(26, 18, 30))
    }

    @Test func skinButtonsIgnoreOtherReminders() async throws {
        let setup = try await setup(start: TestTime.date(26, 7, 5))
        let checkIn = ReminderPayload(kind: .checkIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 7))
        #expect(try await setup.handler.handle(actionIdentifier: ReminderAction.calm.identifier, payload: checkIn) == .ignored)
        let skin = ReminderPayload(kind: .skinCheckIn, childID: setup.harness.child.id, fireDate: TestTime.date(26, 18, 30))
        #expect(try await setup.handler.handle(actionIdentifier: ReminderAction.good.identifier, payload: skin) == .ignored)
    }

    @Test func answeringSkipsThatEveningAndClearsItsNotification() async throws {
        let setup = try await setup(start: TestTime.date(26, 9))
        try await setup.scheduler.refresh()
        #expect(skinIDs(setup.center).first == "calicare.skin.2026-09-26")

        try await setup.harness.logs.log(.skinToday, value: .skin(.calm), child: setup.harness.child.id, source: .intent)
        try await setup.scheduler.refresh()
        #expect(skinIDs(setup.center).first == "calicare.skin.2026-09-27")
        #expect(setup.center.removedDelivered.contains("calicare.skin.2026-09-26"))
    }

    @Test func anEveningAnswerAfterSevenStillSkipsToday() async throws {
        let setup = try await setup(start: TestTime.date(26, 21))
        try await setup.harness.logs.log(.skinToday, value: .skin(.flaring), child: setup.harness.child.id, source: .app)
        try await setup.scheduler.refresh()
        #expect(setup.center.removedDelivered.contains("calicare.skin.2026-09-26"))
        #expect(skinIDs(setup.center).first == "calicare.skin.2026-09-27")
    }
}
