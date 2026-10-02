import Core
import Foundation
import Observation

/// Everything the Today screen shows for the current child, read fresh from the
/// shared database so logs from widgets, Siri, and notifications show up.
@MainActor
@Observable
final class TodayModel {
    /// Something just logged from the app, with Undo.
    struct Confirmation: Identifiable, Equatable {
        let entry: LogEntry
        let text: String
        /// Undo brings a deleted log back instead of removing a new one.
        var wasDeleted = false
        var id: UUID { entry.id }
    }

    private(set) var children: [ChildInfo] = []
    private(set) var child: ChildInfo?
    /// The current care day's logs, newest first.
    private(set) var entries: [LogEntry] = []
    private(set) var lastNight: LastNightReport?
    private(set) var week: [WeekDay] = []
    /// The skin answer for the day a skin answer given now would be about.
    private(set) var skin: SkinToday?
    /// The current child's routine steps, morning and evening, paused ones included.
    private(set) var routineSteps: [RoutineStepInfo] = []
    /// The last seven care days' logs, for this week's baths.
    private(set) var weekLogs: [LogEntry] = []
    /// The running care plan's items, by id: for plan steps' "3–4x/day".
    private(set) var planItems: [UUID: PlanItemInfo] = [:]
    /// False until anything has been logged for any child: shows the first-run hint.
    private(set) var hasEverLogged = true
    /// False from 7 PM, when the care day is tonight's.
    private(set) var isDaytime = true
    private(set) var hasLoaded = false
    /// For "by Dad" on the timeline.
    private(set) var myName: String?
    private(set) var householdSize = 1
    var confirmation: Confirmation?
    var problem: String?

    private let calendar = Calendar.autoupdatingCurrent
    private let phrases = LogPhrases()

    func load(now: Date = .now) async {
        do {
            let container = try CaliCareModelContainer.shared()
            let childStore = ChildStore(modelContainer: container)
            children = try await childStore.activeChildren()
            child = try await childStore.currentChild()
            guard let child else {
                clear()
                return
            }
            let setting = CurrentChildSetting()
            if setting.childID != child.id { setting.childID = child.id }

            let today = CareDay.containing(now, calendar: calendar)
            let store = LogStore(modelContainer: container, calendar: calendar)
            let events = try await store
                .events(from: today.adding(days: -6, calendar: calendar), through: today, child: child.id)
            let todaySummary = DaySummary(day: today, events: events, calendar: calendar)
            let previous = DaySummary(day: today.adding(days: -1, calendar: calendar), events: events, calendar: calendar)

            entries = events.filter { today.contains($0.timestamp, calendar: calendar) }.reversed()
            weekLogs = events
            lastNight = LastNightReport.resolve(at: now, today: todaySummary, previous: previous, calendar: calendar)
            week = WeekOverview.days(ending: today, events: events, calendar: calendar)
            let skinDay = SkinDay.day(for: now, calendar: calendar)
            skin = events.last { $0.type == .skinToday && skinDay.contains($0.timestamp, calendar: calendar) }
                .flatMap { if case .skin(let answer)? = $0.value { answer } else { nil } }
            hasEverLogged = try await !store.recent(limit: 1).isEmpty
            routineSteps = try await RoutineStore(modelContainer: container).steps(child: child.id, includeInactive: true)
            let plans = CarePlanStore(modelContainer: container)
            if let active = try await plans.activePlan(child: child.id) {
                planItems = Dictionary(uniqueKeysWithValues: try await plans.items(plan: active.id).map { ($0.id, $0) })
            } else {
                planItems = [:]
            }
            isDaytime = today.isDaytime(now, calendar: calendar)
            myName = AccountSettings().displayName
            householdSize = SyncSettings().householdSize
            hasLoaded = true
        } catch {
            #if DEBUG
            print("CaliCare load failed: \(error)")
            #endif
            problem = "Couldn't load today just now."
            hasLoaded = true
        }
    }

    /// One-tap log from the app for the current child.
    func log(_ type: LogType, value: LogValue? = nil) async {
        guard let child else { return }
        do {
            let saved = try await QuickLog.live().record(type, value: value, childID: child.id, source: .app)
            confirmation = Confirmation(entry: saved.entry, text: phrases.logged(saved.entry, childName: saved.child.name))
            await afterChange()
        } catch {
            problem = "Couldn't save that. Please try again."
        }
    }

    /// Saves a note for the current child. Returns false (with `problem` set) if it wasn't saved.
    func logNote(_ text: String) async -> Bool {
        guard let child else { return false }
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            let entry = try await store.log(.note, child: child.id, source: .app, note: text)
            confirmation = Confirmation(entry: entry, text: phrases.logged(entry, childName: child.name))
            await afterChange()
            return true
        } catch LogStoreError.emptyNote {
            problem = "A note needs a few words."
            return false
        } catch {
            problem = "Couldn't save that. Please try again."
            return false
        }
    }

    func undo(_ confirmation: Confirmation) async {
        if self.confirmation == confirmation { self.confirmation = nil }
        if confirmation.wasDeleted {
            await restore(confirmation.entry)
        } else {
            await delete(confirmation.entry)
        }
    }

    /// Ticks off one routine step.
    func tick(_ step: RoutineStepInfo) async {
        guard child != nil else { return }
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            let entry = try await store.logRoutineStep(step.id, source: .app)
            confirmation = Confirmation(entry: entry, text: "Done: \(step.name), \(time(entry.timestamp)).")
            await load()
            Task { await LogChanges.didChange() }
        } catch {
            problem = "Couldn't save that. Please try again."
        }
    }

    /// Logs one of the plan's baths.
    func logBath(_ item: PlanItemInfo) async {
        guard let child else { return }
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            let entry = try await store.logBath(item.id, child: child.id, source: .app)
            confirmation = Confirmation(entry: entry, text: "Logged \(item.text), \(time(entry.timestamp)).")
            await load()
            Task { await LogChanges.didChange() }
        } catch {
            problem = "Couldn't save that. Please try again."
        }
    }

    /// The plan's patch-test wait, and tests running, ready, or checked this week.
    var patchTests: PatchTests {
        PatchTests(items: Array(planItems.values), logs: weekLogs, now: .now)
    }

    /// Starts a patch test and, when the plan says how long to wait, a reminder to check it.
    func startPatchTest(what: String, where spot: String) async {
        guard let child else { return }
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            let entry = try await store.logPatchTest(what: what, where: spot, child: child.id, source: .app)
            if let wait = patchTests.wait {
                // In the background: the notification service can be slow to answer.
                Task.detached {
                    if await NotificationPermission.status() == .notDetermined { _ = await NotificationPermission.request() }
                    await PatchReminder.schedule(for: entry, at: entry.timestamp.addingTimeInterval(wait))
                }
            }
            confirmation = Confirmation(entry: entry, text: "Patch test started, \(time(entry.timestamp)).")
            await load()
            Task { await LogChanges.didChange() }
        } catch {
            problem = "Couldn't start the patch test. Please try again."
        }
    }

    /// Records what the parent saw, and drops the reminder.
    func setPatchResult(_ test: PatchTests.Test, _ result: PatchResult) async {
        PatchReminder.cancel(for: test.entry)
        _ = await update(test.entry, value: .patch(result), note: test.entry.note, timestamp: test.entry.timestamp)
    }

    /// The running plan's baths and this week's count.
    var bathWeek: BathWeek {
        BathWeek(items: Array(planItems.values).sorted { $0.order < $1.order }, logs: weekLogs, now: .now, calendar: calendar)
    }

    func progress(_ time: RoutineTime) -> RoutineProgress {
        RoutineProgress(time: time, steps: routineSteps, entries: entries)
    }

    /// Swipe to delete: soft delete, with Undo in the Logged line.
    func deleteWithUndo(_ entry: LogEntry) async {
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            try await store.delete(entry.id)
            entries.removeAll { $0.id == entry.id }
            // Undo shows at once; widgets and reminders refresh after.
            confirmation = Confirmation(entry: entry, text: phrases.removed(entry), wasDeleted: true)
            Task { await afterChange() }
        } catch {
            problem = "Couldn't delete that. Please try again."
        }
    }

    /// Where a flare was ("Add where"). Returns false (with `problem` set) if it wasn't saved.
    func setBodyAreas(_ areas: [BodyArea], on entry: LogEntry) async -> Bool {
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            try await store.setBodyAreas(areas, on: entry.id)
            // The sheet closes as soon as it's saved; the refresh follows.
            Task { await afterChange() }
            return true
        } catch {
            problem = "Couldn't save where. Please try again."
            return false
        }
    }

    private func restore(_ entry: LogEntry) async {
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            try await store.restore(entry.id)
            await afterChange()
        } catch {
            problem = "Couldn't bring that back. Please try again."
        }
    }

    func update(_ entry: LogEntry, value: LogValue?, note: String?, timestamp: Date) async -> Bool {
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            try await store.update(entry.id, value: value, note: note, timestamp: timestamp)
            await afterChange()
            return true
        } catch LogStoreError.emptyNote {
            problem = "A note needs a few words."
            return false
        } catch {
            problem = "Couldn't save that change. Please try again."
            return false
        }
    }

    /// Soft delete: the log is hidden everywhere but kept for sync.
    func delete(_ entry: LogEntry) async {
        do {
            let store = LogStore(modelContainer: try CaliCareModelContainer.shared(), calendar: calendar)
            try await store.delete(entry.id)
            if confirmation?.entry.id == entry.id { confirmation = nil }
            await afterChange()
        } catch {
            problem = "Couldn't delete that. Please try again."
        }
    }

    /// Switches whose day this is. Widgets, Siri, and reminders follow along.
    func select(_ id: UUID) async {
        guard id != child?.id else { return }
        CurrentChildSetting().childID = id
        confirmation = nil
        await afterChange()
    }

    /// A ticked routine step shows its own name ("Bath"); everything else its usual title.
    func title(for entry: LogEntry) -> String {
        if let id = entry.routineStepID, let step = routineSteps.first(where: { $0.id == id }) {
            return step.name
        }
        if entry.type == .bath, let id = entry.routineStepID, let item = planItems[id] {
            return item.text
        }
        return phrases.title(for: entry)
    }

    /// "by Dad", or nil when it's just one person.
    func byline(for entry: LogEntry) -> String? {
        LoggedBy.byline(entry.loggedBy, myName: myName, householdSize: householdSize)
    }

    func time(_ date: Date) -> String {
        phrases.time(date)
    }

    private func afterChange() async {
        await load()
        await LogChanges.didChange()
    }

    private func clear() {
        entries = []
        lastNight = nil
        week = []
        skin = nil
        routineSteps = []
        planItems = [:]
        weekLogs = []
        hasLoaded = true
    }
}
