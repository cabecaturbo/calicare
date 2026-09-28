import Core
import Foundation
import Observation
import UserNotifications

/// Reminder settings, and the short explanation before the system asks.
@MainActor
@Observable
final class ReminderController {
    /// Why the explanation sheet is showing.
    enum Offer: Equatable {
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

    /// Onboarding: asks for permission right away if it's undecided, then turns it on.
    func turnOnAsking(_ kind: ReminderKind) async {
        if status == .notDetermined {
            _ = await NotificationPermission.request()
            status = await NotificationPermission.status()
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        settings[kind].isOn = true
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

    func acceptOffer() async {
        let accepted = offer
        offer = nil
        store.hasOfferedReminders = true
        let granted = await NotificationPermission.request()
        status = await NotificationPermission.status()
        guard granted else { return }
        if case .toggle(let kind)? = accepted { settings[kind].isOn = true }
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
}
