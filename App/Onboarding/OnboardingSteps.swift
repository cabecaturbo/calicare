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
                title: "Two quiet reminders.",
                detail: "One question each. Answer right from the alert."
            )
            VStack(spacing: 0) {
                Hairline()
                ForEach(kinds, id: \.self) { kind in
                    LedgerRow {
                        Toggle(isOn: Binding(
                            get: { reminders.settings[kind].isOn },
                            set: { turn($0, kind) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ReminderCopy.settingsTitle(kind))
                                    .textStyle(.control)
                                    .foregroundStyle(palette.ink)
                                Text(question(kind))
                                    .textStyle(.meta)
                                    .foregroundStyle(palette.graphite)
                            }
                        }
                        .tint(palette.indigo)
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
                            .tint(palette.indigo)
                            .accessibilityLabel("\(ReminderCopy.settingsTitle(kind)) time")
                        }
                    }
                }
            }
            Text(primed ? "Your iPhone will ask once. We skip a day if you already answered." : "We skip a day if you already answered.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
        } footer: {
            if anyOn {
                Button("Continue", action: onContinue)
                    .buttonStyle(.primary)
            } else {
                Button("Not now", action: onContinue)
                    .buttonStyle(.textLink)
            }
        }
        .task { await reminders.reload() }
    }

    /// The one question each reminder asks.
    private func question(_ kind: ReminderKind) -> String {
        kind == .checkIn ? "How was last night?" : "How was \(childName.map { "\($0)’s" } ?? "their") skin today?"
    }

    private var anyOn: Bool { kinds.contains { reminders.settings[$0].isOn } }

    private func turn(_ isOn: Bool, _ kind: ReminderKind) {
        guard isOn else {
            reminders.setOn(false, for: kind)
            return
        }
        Task {
            if reminders.status == .notDetermined, !primed {
                withAnimation(.easeOut(duration: 0.25)) { primed = true }
                try? await Task.sleep(for: .seconds(1.2))
            }
            await reminders.turnOnAsking(kind)
        }
    }
}

/// The Itchy widget: a real screenshot of it on the Home Screen, "Show me how",
/// and "Not now". The Lock Screen and Control Center wait in Settings › Quick logging.
struct LogAnywhereStep: View {
    @State private var showing: GuidePath?
    @State private var watchedOne = false
    let onFinish: () -> Void

    var body: some View {
        OnboardingPage {
            OnboardingHeading(
                title: "Log from your Home Screen.",
                detail: "One tap logs it. The app stays closed."
            )
            GuideScreenshot(asset: GuidePath.homeScreen.doneAsset, tap: nil)
                .frame(height: 380)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("The Itchy widget on a Home Screen")
        } footer: {
            Button("Show me how") { showing = .homeScreen }
                .buttonStyle(.primary)
            Button(watchedOne ? "Go to Today" : "Not now", action: onFinish)
                .buttonStyle(.textLink)
        }
        .fullScreenCover(item: $showing, onDismiss: { watchedOne = true }) { path in
            SetupGuide(path: path)
                .nightAwarePalette()
        }
    }
}
