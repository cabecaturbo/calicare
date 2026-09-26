import Core
import SwiftUI

/// Screen 3: widget, Siri, and Action Button, one at a time. Every part is skippable.
struct QuickLoggingStep: View {
    enum Part: Int, CaseIterable {
        case widget, siri, actionButton
    }

    @Environment(\.palette) private var palette
    @State private var part: Part = .widget
    let childName: String?
    let onFinish: () -> Void

    init(childName: String?, onFinish: @escaping () -> Void) {
        self.childName = childName
        self.onFinish = onFinish
    }

    var body: some View {
        OnboardingPage {
            HStack(alignment: .firstTextBaseline) {
                Text("Part \(part.rawValue + 1) of \(Part.allCases.count)")
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                Spacer()
                Button("Skip setup", action: onFinish)
                    .font(Typography.button)
                    .foregroundStyle(palette.sageDark)
                    .frame(minHeight: TouchTarget.minimum)
                    .accessibilityHint("Goes straight to Today. You can find these steps later in Settings.")
            }
            switch part {
            case .widget: WidgetSetupGuide(childName: childName)
            case .siri: SiriSetupGuide()
            case .actionButton: ActionButtonSetupGuide()
            }
        } footer: {
            PrimaryButton(title: isLast ? "Start using CaliCare" : "Next", action: advance)
            SecondaryButton(title: isLast ? "Skip for now" : "Skip this step", action: advance)
        }
    }

    private var isLast: Bool { part == Part.allCases.last }

    private func advance() {
        guard let next = Part(rawValue: part.rawValue + 1) else {
            onFinish()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { part = next }
    }
}
