import Core
import SwiftUI
import UIKit
import UserNotifications

/// On/off and time for each reminder. Changes reschedule right away.
struct ReminderSettingsSection: View {
    @Environment(ReminderController.self) private var reminders
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            if reminders.status == .denied {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Notifications are off for CaliCare. You can turn them on in iOS Settings whenever you like.")
                        .font(Typography.callout)
                        .foregroundStyle(palette.muted)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(Typography.button)
                    .frame(minHeight: TouchTarget.minimum)
                }
            }
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                row(for: kind)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Answer right from the notification. If you skip one, nothing else happens.")
        }
        .listRowBackground(palette.card)
    }

    private func row(for kind: ReminderKind) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(isOn: Binding(
                get: { reminders.settings[kind].isOn },
                set: { reminders.setOn($0, for: kind) }
            )) {
                Text(ReminderCopy.settingsTitle(kind))
                    .font(Typography.body)
                    .foregroundStyle(palette.ink)
            }
            .frame(minHeight: TouchTarget.minimum)

            if reminders.settings[kind].isOn {
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { reminders.time(for: kind) },
                        set: { reminders.setTime($0, for: kind) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .font(Typography.callout)
                .foregroundStyle(palette.muted)
                .frame(minHeight: TouchTarget.minimum)
            }
        }
    }
}
