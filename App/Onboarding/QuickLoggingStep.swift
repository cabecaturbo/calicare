import Core
import SwiftUI

/// Screen 3: Home Screen widget, Lock Screen widget, Siri, and Action Button,
/// one at a time. Every part can be skipped.
struct QuickLoggingStep: View {
    enum Part: Int, CaseIterable {
        case widget, lockScreen, siri, actionButton
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
            HStack(alignment: .center) {
                Text("Part \(part.rawValue + 1) of \(Part.allCases.count)")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Spacer()
                Button("Skip setup", action: onFinish)
                    .buttonStyle(.textLink)
                    .accessibilityHint("Goes straight to Today. You can find these steps later in Settings.")
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.x4)

            Group {
                switch part {
                case .widget: WidgetSetupGuide(childName: childName)
                case .lockScreen: LockScreenSetupGuide()
                case .siri: SiriSetupGuide()
                case .actionButton: ActionButtonSetupGuide()
                }
            }
            .id(part)
        } footer: {
            Button(isLast ? "Done, go to Today" : "Done", action: advance)
                .buttonStyle(.primary)
            Button(isLast ? "Skip for now" : "Skip this one", action: advance)
                .buttonStyle(.textLink)
        }
    }

    private var isLast: Bool { part == Part.allCases.last }

    private func advance() {
        guard let next = Part(rawValue: part.rawValue + 1) else {
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { part = next }
    }
}
