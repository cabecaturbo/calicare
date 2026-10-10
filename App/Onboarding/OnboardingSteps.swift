import Core
import SwiftUI

/// The morning check-in and the evening skin check-in, each a switch and a
/// time. Turning the first one on shows one line about the system prompt,
/// then asks; if the parent says no, the switch goes back off with a note.
struct RemindersStep: View {
    @Environment(\.palette) private var palette
    @Environment(ReminderController.self) private var reminders
    @State private var primed = false
    @State private var pending: ReminderKind?
    @State private var denied = false
    let childName: String?
    let onContinue: () -> Void

    private let kinds: [ReminderKind] = [.checkIn, .skinCheckIn]

    var body: some View {
        OnboardingPage {
            OnboardingHeading(
                title: "Gentle reminders",
                detail: "Morning: log \(childName.map { "\($0)’s" } ?? "your child’s") night. Evening: log their skin. Answer right from the notification."
            )
            VStack(spacing: 0) {
                Hairline()
                ForEach(kinds, id: \.self) { kind in
                    LedgerRow {
                        Toggle(isOn: Binding(
                            get: { pending == kind || reminders.settings[kind].isOn },
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
            if let note {
                Text(note)
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x4)
                    .transition(Motion.fade)
            }
        } footer: {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .disabled(!anyOn)
            Button("Skip for now", action: onContinue)
                .buttonStyle(.textLink)
        }
        .task { await reminders.reload() }
    }

    private var anyOn: Bool { kinds.contains { reminders.settings[$0].isOn } }

    private var note: String? {
        if denied { return "Notifications are off for Cali Care. You can turn them on in iOS Settings." }
        if primed { return "Your iPhone will ask once. Reminders skip anything you’ve already logged." }
        return nil
    }

    private func turn(_ isOn: Bool, _ kind: ReminderKind) {
        guard isOn else {
            reminders.setOn(false, for: kind)
            return
        }
        pending = kind
        Task {
            if reminders.status == .notDetermined, !primed {
                withMotion(.quick) { primed = true }
                try? await Task.sleep(for: .seconds(1.2))
            }
            let allowed = await reminders.turnOnAsking(kind)
            withMotion(.quick) {
                pending = nil
                primed = false
                denied = !allowed
            }
        }
    }
}

/// Lock Screen first (then Home Screen or Control Center): what Log does, the
/// widget in place on a real screenshot, and a button into that path's guide.
struct LogAnywhereStep: View {
    @Environment(\.palette) private var palette
    @State private var path: GuidePath = .lockScreen
    @State private var showing: GuidePath?
    @State private var watchedOne = false
    let onFinish: () -> Void

    var body: some View {
        OnboardingPage {
            OnboardingHeading(title: "Log in one tap", detail: path.pitch)
            VStack(spacing: Spacing.x5) {
                Picker("Where", selection: $path) {
                    Text("Lock Screen").tag(GuidePath.lockScreen)
                    Text("Home Screen").tag(GuidePath.homeScreen)
                    Text("Control Center").tag(GuidePath.controlCenter)
                }
                .pickerStyle(.segmented)
                .tint(palette.accent)
                GuideBand(asset: path.doneAsset, band: path.doneBand)
                    .id(path)
                    .transition(Motion.fade)
                    .accessibilityLabel("\(path.title), finished")
                Text("Siri works too: “Log an itch in Cali Care.”")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            .padding(.horizontal, Spacing.margin)
            .motion(.quick, value: path)
        } footer: {
            Button(path.addTitle) { showing = path }
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

extension GuidePath {
    /// What Log does, and how it works from here.
    var pitch: String {
        switch self {
        case .lockScreen: "One tap on Log records an itch. Add the Lock Screen widget, then tap Log. Unlock with Face ID and it’s saved."
        case .homeScreen: "One tap on Log records an itch. Add the widget to your Home Screen, then tap Log and it’s saved."
        case .controlCenter: "One tap on Log records an itch. Add Log to Control Center, then swipe down and tap it."
        }
    }

    var addTitle: String {
        switch self {
        case .lockScreen: "Add it to my Lock Screen"
        case .homeScreen: "Add it to my Home Screen"
        case .controlCenter: "Add it to Control Center"
        }
    }

    /// The part of the finished screenshot where Log sits, top to bottom as
    /// fractions of its height, so onboarding shows the widget in place.
    var doneBand: ClosedRange<CGFloat> {
        switch self {
        case .lockScreen: 0.70...0.90
        case .homeScreen: 0.07...0.32
        case .controlCenter: 0.08...0.30
        }
    }
}
