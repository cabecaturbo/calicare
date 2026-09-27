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
        LedgerSection(
            "Reminders",
            footnote: "Answer right from the notification. If you skip one, nothing else happens."
        ) {
            if reminders.status == .denied {
                LedgerRow {
                    Text("Notifications are off for CaliCare. You can turn them on in iOS Settings whenever you like.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                } trailing: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.textLink)
                }
            }
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                row(for: kind)
            }
        }
    }

    @ViewBuilder
    private func row(for kind: ReminderKind) -> some View {
        LedgerRow {
            Toggle(isOn: Binding(
                get: { reminders.settings[kind].isOn },
                set: { reminders.setOn($0, for: kind) }
            )) {
                Text(ReminderCopy.settingsTitle(kind))
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            }
            .tint(palette.indigo)
        }

        if reminders.settings[kind].isOn {
            LedgerRow {
                Text("Time")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            } trailing: {
                DatePicker(
                    "\(ReminderCopy.settingsTitle(kind)) time",
                    selection: Binding(
                        get: { reminders.time(for: kind) },
                        set: { reminders.setTime($0, for: kind) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .tint(palette.indigo)
            }
        }
    }
}
