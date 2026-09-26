#if DEBUG
import Core
import SwiftUI
import UserNotifications

/// Debug builds only: sends a real reminder in 5 seconds so its buttons can be tried.
/// Go to the Home Screen (or lock the simulator) before it arrives.
struct TryNotificationSection: View {
    @Environment(ReminderController.self) private var reminders
    @Environment(\.palette) private var palette
    @State private var message: String?

    var body: some View {
        Section {
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                Button("\(ReminderCopy.settingsTitle(kind)) in 5 seconds") {
                    Task { await send(kind) }
                }
                .font(Typography.body)
                .frame(minHeight: TouchTarget.minimum)
                .disabled(reminders.status != .authorized)
            }
            if let message {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
            }
        } header: {
            Text("Try a notification")
        } footer: {
            Text(reminders.status == .authorized
                ? "Then go to the Home Screen, long-press the notification, and tap a button."
                : "Turn on a reminder first so notifications are allowed.")
        }
        .listRowBackground(palette.card)
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
