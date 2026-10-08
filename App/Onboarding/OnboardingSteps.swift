import Core
import SwiftUI

/// The morning check-in and the evening skin check-in, each a switch and a
/// time. Turning one on shows one line about the system prompt, then asks.
struct RemindersStep: View {
    @Environment(\.palette) private var palette
    @Environment(ReminderController.self) private var reminders
    @State private var primed = false
    let childName: String?
    let onContinue: () -> Void

    private let kinds: [ReminderKind] = [.checkIn, .skinCheckIn]

    var body: some View {
        OnboardingPage {
            OnboardingHeading(
                title: "Gentle reminders",
                detail: "A nudge to log \(childName.map { "\($0)’s" } ?? "the") night in the morning, and skin in the evening. Answer right from the notification."
            )
            VStack(spacing: 0) {
                Hairline()
                ForEach(kinds, id: \.self) { kind in
                    LedgerRow {
                        Toggle(isOn: Binding(
                            get: { reminders.settings[kind].isOn },
                            set: { turn($0, kind) }
                        )) {
                            Text(ReminderCopy.settingsTitle(kind))
                                .textStyle(.control)
                                .foregroundStyle(palette.ink)
                        }
                        .tint(palette.accent)
                    }
                    if reminders.settings[kind].isOn {
                        LedgerRow {
                            Text("Time")
                                .textStyle(.control)
                                .foregroundStyle(palette.graphite)
                        } trailing: {
                            DatePicker(
                                "Time",
                                selection: Binding(get: { reminders.time(for: kind) }, set: { reminders.setTime($0, for: kind) }),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .tint(palette.accent)
                            .accessibilityLabel("\(ReminderCopy.settingsTitle(kind)) time")
                        }
                    }
                }
            }
            if primed {
                Text("Your iPhone will ask once. Reminders skip anything you’ve already logged.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x4)
                    .transition(Motion.fade)
            }
        } footer: {
            if anyOn {
                Button("Continue", action: onContinue)
                    .buttonStyle(.primary)
            } else {
                Button("Skip for now", action: onContinue)
                    .buttonStyle(.textLink)
            }
        }
        .task { await reminders.reload() }
    }

    private var anyOn: Bool { kinds.contains { reminders.settings[$0].isOn } }

    private func turn(_ isOn: Bool, _ kind: ReminderKind) {
        guard isOn else {
            reminders.setOn(false, for: kind)
            return
        }
        Task {
            if reminders.status == .notDetermined, !primed {
                withMotion(.quick) { primed = true }
                try? await Task.sleep(for: .seconds(1.2))
            }
            await reminders.turnOnAsking(kind)
        }
    }
}

/// Home Screen, Lock Screen, or Control Center: a real screenshot of the
/// finished setup, "Show me how", and "Skip for now".
struct LogAnywhereStep: View {
    @Environment(\.palette) private var palette
    @State private var path: GuidePath = .homeScreen
    @State private var showing: GuidePath?
    @State private var watchedOne = false
    let onFinish: () -> Void

    var body: some View {
        OnboardingPage {
            OnboardingHeading(
                title: "Log from anywhere",
                detail: "One tap from your Home Screen, Lock Screen, or Control Center. The app never opens."
            )
            VStack(spacing: Spacing.x5) {
                Picker("Where", selection: $path) {
                    Text("Home").tag(GuidePath.homeScreen)
                    Text("Lock").tag(GuidePath.lockScreen)
                    Text("Control Center").tag(GuidePath.controlCenter)
                }
                .pickerStyle(.segmented)
                GuideScreenshot(asset: path.doneAsset, tap: nil)
                    .frame(height: 380)
                    .id(path)
                    .transition(Motion.fade)
                    .accessibilityLabel("\(path.title), finished")
                Text("Siri works too: “Log itching in Cali Care.”")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            .padding(.horizontal, Spacing.margin)
            .motion(.quick, value: path)
        } footer: {
            Button("Show me how") { showing = path }
                .buttonStyle(.primary)
            Button(watchedOne ? "Go to Today" : "Skip for now", action: onFinish)
                .buttonStyle(.textLink)
        }
        .fullScreenCover(item: $showing, onDismiss: { watchedOne = true }) { path in
            SetupGuide(path: path)
                .nightAwarePalette()
        }
    }
}
