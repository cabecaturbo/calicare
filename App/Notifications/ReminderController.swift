import Core
import Foundation
import Observation
import UserNotifications

/// Reminder settings and the kind, one-time offer to turn them on.
@MainActor
@Observable
final class ReminderController {
    /// Why the explanation sheet is showing.
    enum Offer: Equatable {
        /// After the first log. Accepting turns on all reminders.
        case firstLog
        /// A Settings toggle while permission is undecided. Accepting turns on that one.
        case toggle(ReminderKind)
    }

    private(set) var settings: ReminderSettings
    private(set) var status: UNAuthorizationStatus = .notDetermined
    var offer: Offer?

    private let store = ReminderSettingsStore()

    init() {
        settings = store.settings
    }

    func reload() async {
        settings = store.settings
        status = await NotificationPermission.status()
    }

    func setOn(_ isOn: Bool, for kind: ReminderKind) {
        if isOn, status == .notDetermined {
            offer = .toggle(kind)
            return
        }
        settings[kind].isOn = isOn
        save()
    }

    func setTime(_ date: Date, for kind: ReminderKind) {
        let parts = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        settings[kind].hour = parts.hour ?? settings[kind].hour
        settings[kind].minute = parts.minute ?? settings[kind].minute
        save()
    }

    /// The reminder's time today, for a time picker.
    func time(for kind: ReminderKind) -> Date {
        let slot = settings[kind]
        return Calendar.autoupdatingCurrent.date(
            bySettingHour: slot.hour, minute: slot.minute, second: 0, of: .now
        ) ?? .now
    }

    /// Offers reminders once, the first time the app opens after something was logged.
    func offerAfterFirstLogIfNeeded() async {
        guard offer == nil, !store.hasOfferedReminders else { return }
        await reload()
        guard status == .notDetermined, await hasAnyLog() else { return }
        store.hasOfferedReminders = true
        offer = .firstLog
    }

    func acceptOffer() async {
        let accepted = offer
        offer = nil
        store.hasOfferedReminders = true
        let granted = await NotificationPermission.request()
        status = await NotificationPermission.status()
        guard granted else { return }
        switch accepted {
        case .toggle(let kind): settings[kind].isOn = true
        case .firstLog, nil: settings.turnAllOn()
        }
        save()
    }

    func declineOffer() {
        offer = nil
        store.hasOfferedReminders = true
    }

    private func save() {
        store.settings = settings
        Task { try? await ReminderScheduler.live().refresh() }
    }

    private func hasAnyLog() async -> Bool {
        guard let container = try? CaliCareModelContainer.shared(),
              let recent = try? await LogStore(modelContainer: container).recent(limit: 1)
        else { return false }
        return !recent.isEmpty
    }
}
