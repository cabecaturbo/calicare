#if DEBUG
import Core
import SwiftUI
import UserNotifications

/// Debug builds only: sends a real reminder in 5 seconds so its buttons can be tried.
/// Go to the Home Screen (or lock the simulator) before it arrives.
struct TryNotificationSection: View {
    @Environment(ReminderController.self) private var reminders
    @State private var message: String?

    var body: some View {
        SettingsSection("Try a notification", footnote: footnote) {
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                Button {
                    Task { await send(kind) }
                } label: {
                    SettingsLabel("\(ReminderCopy.settingsTitle(kind)) in 5 seconds")
                }
                .disabled(reminders.status != .authorized)
            }
        }
    }

    private var footnote: String {
        if let message { return message }
        return reminders.status == .authorized
            ? "Then go to the Home Screen, long-press the notification, and tap a button."
            : "Turn on a reminder first so notifications are allowed."
    }

    private func send(_ kind: ReminderKind) async {
        do {
            try await ReminderScheduler.live().sendTest(kind)
            message = "\(ReminderCopy.settingsTitle(kind)) arrives in 5 seconds."
        } catch {
            message = "Couldn't send it: \(error.localizedDescription)"
        }
    }
}
#endif
