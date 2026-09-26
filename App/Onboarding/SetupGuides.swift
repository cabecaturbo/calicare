import AppIntents
import Core
import SwiftUI

/// Add the Itchy widget to the Home Screen. Shown in onboarding and Settings.
struct WidgetSetupGuide: View {
    @Environment(\.palette) private var palette
    let childName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            GuideHeading(
                title: "Add the Itchy widget",
                detail: "One tap on your Home Screen logs itching\(childName.map { " for \($0)" } ?? ""). The app never opens."
            )
            HStack {
                Spacer()
                WidgetMock()
                Spacer()
            }
            SetupSteps(steps: [
                "Go to your Home Screen. Touch and hold an empty spot until the apps jiggle.",
                "Tap Edit in the top corner, then Add Widget.",
                "Search for CaliCare, pick Itchy, and tap Add Widget.",
            ])
            Text("There's also a bigger Quick log widget, and Lock Screen widgets.")
                .font(Typography.callout)
                .foregroundStyle(palette.muted)
        }
    }
}

/// "Log itching in Cali Care", with Apple's own Siri tip.
struct SiriSetupGuide: View {
    @Environment(\.palette) private var palette
    @State private var showTip = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            GuideHeading(
                title: "Ask Siri",
                detail: "Nothing to set up. Just say it, even with your hands full or the phone locked."
            )
            SiriTipView(intent: LogItchIntent(), isVisible: $showTip)
                .siriTipViewStyle(palette.isNight ? .dark : .light)
            Text("Also try \u{201C}Log a rough night in Cali Care\u{201D} or \u{201C}Undo in Cali Care.\u{201D}")
                .font(Typography.callout)
                .foregroundStyle(palette.muted)
        }
    }
}

/// Put Log Itching on the Action Button, or in Control Center.
struct ActionButtonSetupGuide: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            GuideHeading(
                title: "Use the Action Button",
                detail: "On iPhones with an Action Button, one press can log itching."
            )
            SetupSteps(steps: [
                "Open the Settings app and tap Action Button.",
                "Swipe to Shortcut, then tap Choose a Shortcut.",
                "Pick CaliCare, then Log Itching.",
            ])
            Text("No Action Button? Add the Log itching control to Control Center: swipe down from the top right, tap +, then Add a Control.")
                .font(Typography.callout)
                .foregroundStyle(palette.muted)
        }
    }
}

private struct GuideHeading: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(Typography.body)
                .foregroundStyle(palette.ink)
        }
    }
}

/// Numbered steps in a card.
struct SetupSteps: View {
    @Environment(\.palette) private var palette
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text("\(index + 1)")
                        .font(Typography.headline)
                        .foregroundStyle(palette.sageDark)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(palette.severityLow, in: Circle())
                        .accessibilityHidden(true)
                    Text(step)
                        .font(Typography.body)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1). \(step)")
            }
        }
        .cardStyle()
    }
}

/// A picture of the small Itchy widget, so parents know what to look for.
private struct WidgetMock: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: LogType.itchEpisode.symbol)
                .font(.system(size: 30, weight: .medium))
            Text("Itchy")
                .font(.custom("Fraunces-Medium", fixedSize: 20))
        }
        .foregroundStyle(palette.onAccent)
        .frame(width: 120, height: 120)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityElement()
        .accessibilityLabel("The Itchy widget: a sage square with a hand and the word Itchy.")
    }
}
