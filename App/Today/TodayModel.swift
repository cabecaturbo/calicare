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
        var id: UUID { entry.id }
    }

    private(set) var children: [ChildInfo] = []
    private(set) var child: ChildInfo?
    /// The current care day's logs, newest first.
    private(set) var entries: [LogEntry] = []
    private(set) var lastNight: LastNightReport?
    private(set) var week: [WeekDay] = []
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
            let events = try await LogStore(modelContainer: container, calendar: calendar)
                .events(from: today.adding(days: -6, calendar: calendar), through: today, child: child.id)
            let todaySummary = DaySummary(day: today, events: events, calendar: calendar)
            let previous = DaySummary(day: today.adding(days: -1, calendar: calendar), events: events, calendar: calendar)

            entries = events.filter { today.contains($0.timestamp, calendar: calendar) }.reversed()
            lastNight = LastNightReport.resolve(at: now, today: todaySummary, previous: previous, calendar: calendar)
            week = WeekOverview.days(ending: today, events: events, calendar: calendar)
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

    func undo(_ confirmation: Confirmation) async {
        if self.confirmation == confirmation { self.confirmation = nil }
        await delete(confirmation.entry)
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

    func title(for entry: LogEntry) -> String {
        phrases.title(for: entry)
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
        hasLoaded = true
    }
}
