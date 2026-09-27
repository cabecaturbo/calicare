import Core
import SwiftUI

/// Screen 3: Home Screen widget, Lock Screen widget, Siri, and Action Button,
/// one at a time, then an optional offer to share with a partner. Every part
/// can be skipped.
struct QuickLoggingStep: View {
    enum Part: Int, CaseIterable {
        case widget, lockScreen, siri, actionButton, share
    }

    @Environment(\.palette) private var palette
    @Environment(AccountController.self) private var account
    @State private var part: Part = .widget
    @State private var showingAccount = false
    let childName: String?
    let onFinish: () -> Void

    init(childName: String?, onFinish: @escaping () -> Void) {
        self.childName = childName
        self.onFinish = onFinish
    }

    var body: some View {
        OnboardingPage {
            HStack(alignment: .center) {
                Text("Part \(part.rawValue + 1) of \(parts.count)")
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
                case .share: ShareSetupGuide()
                }
            }
            .id(part)
        } footer: {
            if part == .share {
                Button("Share logs with your partner") { showingAccount = true }
                    .buttonStyle(.primary)
                Button("Not now, go to Today", action: onFinish)
                    .buttonStyle(.textLink)
            } else {
                Button(isLast ? "Done, go to Today" : "Done", action: advance)
                    .buttonStyle(.primary)
                Button(isLast ? "Skip for now" : "Skip this one", action: advance)
                    .buttonStyle(.textLink)
            }
        }
        .sheet(isPresented: $showingAccount, onDismiss: finishIfSignedIn) {
            AccountSheet()
                .environment(account)
                .nightAwarePalette()
        }
    }

    /// The share offer only appears when this build can make accounts.
    private var parts: [Part] {
        Part.allCases.filter { $0 != .share || account.isAvailable }
    }

    private var isLast: Bool { part == parts.last }

    private func advance() {
        guard let index = parts.firstIndex(of: part), index + 1 < parts.count else {
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { part = parts[index + 1] }
    }

    private func finishIfSignedIn() {
        if case .signedIn = account.state { onFinish() }
    }
}
