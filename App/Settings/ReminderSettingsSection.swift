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
        SettingsSection(
            "Reminders",
            footnote: "Answer right from the notification. If you skip one, nothing else happens."
        ) {
            if reminders.status == .denied {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("Notifications are off for CaliCare. You can turn them on in iOS Settings whenever you like.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.textLink)
                }
                .padding(.vertical, Spacing.x2)
            }
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                row(for: kind)
            }
        }
    }

    @ViewBuilder
    private func row(for kind: ReminderKind) -> some View {
        Toggle(isOn: Binding(
            get: { reminders.settings[kind].isOn },
            set: { reminders.setOn($0, for: kind) }
        )) {
            SettingsLabel(ReminderCopy.settingsTitle(kind))
        }
        .tint(palette.indigo)

        if reminders.settings[kind].isOn {
            DatePicker(
                selection: Binding(
                    get: { reminders.time(for: kind) },
                    set: { reminders.setTime($0, for: kind) }
                ),
                displayedComponents: .hourAndMinute
            ) {
                Text("Time")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            .accessibilityLabel("\(ReminderCopy.settingsTitle(kind)) time")
            .tint(palette.indigo)
        }
    }
}
