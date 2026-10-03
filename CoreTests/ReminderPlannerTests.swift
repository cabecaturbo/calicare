import Core
import Foundation
import Testing

struct ReminderPlannerTests {
    private let planner = ReminderPlanner(calendar: TestTime.calendar)

    private func settings(_ kinds: ReminderKind...) -> ReminderSettings {
        var settings = ReminderSettings()
        for kind in kinds { settings[kind].isOn = true }
        return settings
    }

    private func checkIns(_ reminders: [PlannedReminder]) -> [PlannedReminder] {
        reminders.filter { $0.kind == .checkIn }
    }

    @Test func defaultsAreOffAtTheUsualTimes() {
        let settings = ReminderSettings()
        #expect(settings.checkIn == ReminderSlot(isOn: false, hour: 7, minute: 0))
        #expect(settings.skinCheckIn == ReminderSlot(isOn: false, hour: 18, minute: 30))
        #expect(settings.morningRoutine == ReminderSlot(isOn: false, hour: 7, minute: 30))
        #expect(settings.eveningRoutine == ReminderSlot(isOn: false, hour: 19, minute: 0))
    }

    @Test func nothingWhenEverythingIsOff() async throws {
        let harness = try await TestHarness()
        let plan = planner.plan(settings: ReminderSettings(), child: harness.child, ratedDays: [], now: TestTime.date(26, 6))
        #expect(plan.isEmpty)
    }

    @Test func nothingWithoutAChild() {
        var all = ReminderSettings()
        all.turnAllOn()
        #expect(planner.plan(settings: all, child: nil, ratedDays: [], now: TestTime.date(26, 6)).isEmpty)
    }

    @Test func fourteenDailyCheckInsStartingThisMorning() async throws {
        let harness = try await TestHarness()
        let plan = checkIns(planner.plan(settings: settings(.checkIn), child: harness.child, ratedDays: [], now: TestTime.date(26, 6)))

        #expect(plan.count == ReminderPlanner.checkInDays)
        #expect(plan.first?.fireDate == TestTime.date(26, 7))
        #expect(plan.last?.fireDate == TestTime.date(2026, 10, 9, 7))
        #expect(plan.first?.title == "How was last night for Ada?")
        #expect(plan.first?.body == "One tap is enough.")
        #expect(plan.first?.payload == ReminderPayload(kind: .checkIn, childID: harness.child.id, fireDate: TestTime.date(26, 7)))
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test func startsTomorrowOnceTodaysTimeHasPassed() async throws {
        let harness = try await TestHarness()
        let plan = checkIns(planner.plan(settings: settings(.checkIn), child: harness.child, ratedDays: [], now: TestTime.date(26, 7)))
        #expect(plan.first?.fireDate == TestTime.date(27, 7))
        #expect(plan.count == ReminderPlanner.checkInDays)
    }

    @Test func skipsADayThatAlreadyHasANightRating() async throws {
        let harness = try await TestHarness()
        let today = CareDay(year: 2026, month: 9, day: 26)
        let plan = checkIns(planner.plan(settings: settings(.checkIn), child: harness.child, ratedDays: [today], now: TestTime.date(26, 6)))

        #expect(plan.first?.fireDate == TestTime.date(27, 7))
        #expect(plan.count == ReminderPlanner.checkInDays - 1)
    }

    @Test func aRatingLoggedLateAtNightSkipsTomorrowsCheckIn() async throws {
        let harness = try await TestHarness()
        let lateNight = TestTime.date(26, 23)
        let rated: Set = [CareDay.containing(lateNight, calendar: TestTime.calendar)]
        let plan = checkIns(planner.plan(settings: settings(.checkIn), child: harness.child, ratedDays: rated, now: lateNight))
        #expect(plan.first?.fireDate == TestTime.date(28, 7))
    }

    @Test func usesTheChosenTime() async throws {
        let harness = try await TestHarness()
        var custom = settings(.checkIn)
        custom.checkIn.hour = 6
        custom.checkIn.minute = 45
        let plan = checkIns(planner.plan(settings: custom, child: harness.child, ratedDays: [], now: TestTime.date(26, 5)))
        #expect(plan.first?.fireDate == TestTime.date(26, 6, 45))
    }

    @Test func routinesRepeatDaily() async throws {
        let harness = try await TestHarness()
        let plan = planner.plan(
            settings: settings(.morningRoutine, .eveningRoutine),
            child: harness.child,
            ratedDays: [],
            now: TestTime.date(26, 12)
        )

        #expect(plan.count == 2)
        let morning = try #require(plan.first { $0.kind == .morningRoutine })
        let evening = try #require(plan.first { $0.kind == .eveningRoutine })
        #expect(morning.trigger == .daily(hour: 7, minute: 30))
        #expect(evening.trigger == .daily(hour: 19, minute: 0))
        #expect(morning.title == "Time for Ada's morning routine")
        #expect(evening.title == "Time for Ada's evening routine")
        #expect(morning.body == "Tap Done whenever you're ready.")
        #expect(morning.payload.fireDate == nil)
    }

    @Test func checkInKeepsItsWallClockTimeAcrossDaylightSaving() async throws {
        let harness = try await TestHarness()
        // Clocks spring forward in Los Angeles on March 8, 2026.
        let plan = checkIns(planner.plan(settings: settings(.checkIn), child: harness.child, ratedDays: [], now: TestTime.date(2026, 3, 7, 8)))
        let first = try #require(plan.first)
        guard case .once(let parts) = first.trigger else {
            Issue.record("Expected a one-off trigger")
            return
        }
        #expect(parts.day == 8)
        #expect(parts.hour == 7)
        #expect(parts.minute == 0)
        #expect(first.fireDate == TestTime.date(2026, 3, 8, 7))
    }

    @Test func snoozeComesBackInThirtyMinutes() {
        let payload = ReminderPayload(kind: .morningRoutine, childID: UUID(), fireDate: nil)
        let snoozed = planner.snooze(payload, childName: "Ada")

        #expect(snoozed.trigger == .after(30 * 60))
        #expect(snoozed.payload == payload)
        #expect(snoozed.title == "Time for Ada's morning routine")
        #expect(snoozed.id == "calicare.snooze.morningRoutine")
    }

    @Test func payloadSurvivesTheTripThroughUserInfo() {
        let payload = ReminderPayload(kind: .checkIn, childID: UUID(), fireDate: TestTime.date(26, 7))
        #expect(ReminderPayload(userInfo: payload.userInfo) == payload)

        let routine = ReminderPayload(kind: .eveningRoutine, childID: nil, fireDate: nil)
        #expect(ReminderPayload(userInfo: routine.userInfo) == routine)

        #expect(ReminderPayload(userInfo: ["aps": "someone else's"]) == nil)
    }
}
