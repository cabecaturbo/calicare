import AppIntents
import Core
import SwiftUI

/// Add the Itchy widget to the Home Screen. Shown in onboarding and Settings.
struct WidgetSetupGuide: View {
    let childName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Add the Itchy widget",
                detail: "One tap on your Home Screen logs itching\(childName.map { " for \($0)" } ?? ""). The app never opens."
            )
            VisualSteps(steps: StepFlows.widgetHome)
        }
    }
}

/// Lock Screen widgets: log an itch, or see last night, without unlocking.
struct LockScreenSetupGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Add it to your Lock Screen",
                detail: "Log an itch or see last night without unlocking your phone."
            )
            VisualSteps(steps: StepFlows.widgetLock)
        }
    }
}

/// "Log itching in Cali Care", with Apple's own Siri tip instead of steps.
struct SiriSetupGuide: View {
    @Environment(\.palette) private var palette
    @State private var showTip = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Ask Siri",
                detail: "Nothing to set up. Just say it, even with your hands full or the phone locked."
            )
            VStack(alignment: .leading, spacing: Spacing.x4) {
                SiriTipView(intent: LogItchIntent(), isVisible: $showTip)
                    .siriTipViewStyle(palette.isNight ? .dark : .light)
                Text("Also try \u{201C}Log a rough night in Cali Care\u{201D} or \u{201C}Undo in Cali Care.\u{201D}")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.margin)
        }
    }
}

/// Put Log itching on the Action Button.
struct ActionButtonSetupGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Use the Action Button",
                detail: "On iPhones with an Action Button, one press can log itching."
            )
            VisualSteps(steps: StepFlows.actionButton)
        }
    }
}

/// The Log itch control, for phones without an Action Button.
struct ControlCenterSetupGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.ledeToSection) {
            GuideHeading(
                title: "Add it to Control Center",
                detail: "No Action Button? A Log itch control is one swipe away."
            )
            VisualSteps(steps: StepFlows.controlCenter)
        }
    }
}

private struct GuideHeading: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.titleToLede) {
            Text(title)
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.margin)
    }
}
