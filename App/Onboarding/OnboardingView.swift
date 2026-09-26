import Core
import SwiftUI

/// Three screens, no account: welcome, add a child, set up quick logging.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, addChild, quickLogging
    }

    @Environment(\.palette) private var palette
    @State private var step: Step
    @State private var details = ChildDetails()
    @State private var childName: String?
    @State private var saveError: String?
    @State private var saving = false
    let onFinish: () -> Void

    init(start: Step = .welcome, onFinish: @escaping () -> Void) {
        _step = State(initialValue: start)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
            Group {
                switch step {
                case .welcome:
                    WelcomeStep { go(to: .addChild) }
                case .addChild:
                    AddChildStep(details: $details, error: saveError) { Task { await saveChild() } }
                case .quickLogging:
                    QuickLoggingStep(childName: childName, onFinish: onFinish)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
        }
        .background(palette.background.ignoresSafeArea())
        .task { await loadChildName() }
    }

    private var progress: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? palette.accent : palette.severityLow)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private func go(to next: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func saveChild() async {
        guard details.canSave, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            let child = try await details.save()
            childName = child.name
            saveError = nil
            go(to: .quickLogging)
        } catch {
            saveError = "Couldn't save that just now. Please try again."
        }
    }

    private func loadChildName() async {
        guard childName == nil,
              let child = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).currentChild()
        else { return }
        childName = child.name
    }
}

/// Screen 1: what the app does, in one warm sentence.
private struct WelcomeStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            Image(systemName: "leaf")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text("Welcome to CaliCare")
                .font(Typography.largeTitle)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("A calm place to follow your child's care plan and log how their skin and nights are going, in one tap.")
                .font(Typography.title3)
                .foregroundStyle(palette.ink)
            Text("No account needed. Everything stays on this phone.")
                .font(Typography.callout)
                .foregroundStyle(palette.muted)
        } footer: {
            PrimaryButton(title: "Get started", action: onContinue)
        }
    }
}

/// Screen 2: name is all we need.
private struct AddChildStep: View {
    @Environment(\.palette) private var palette
    @Binding var details: ChildDetails
    let error: String?
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            Text("Who are you caring for?")
                .font(Typography.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            ChildDetailsForm(details: $details) {
                if details.canSave { onContinue() }
            }
            if let error {
                Text(error)
                    .font(Typography.callout)
                    .foregroundStyle(palette.clay)
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onContinue)
                .disabled(!details.canSave)
                .opacity(details.canSave ? 1 : 0.5)
        }
    }
}

/// Scrolling content with a pinned button, so nothing clips at large text sizes.
struct OnboardingPage<Content: View, Footer: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                footer
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .background(palette.background)
        }
    }
}

/// Big filled sage button.
struct PrimaryButton: View {
    @Environment(\.palette) private var palette
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .foregroundStyle(palette.onAccent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .frame(maxWidth: .infinity, minHeight: TouchTarget.night)
                .background(palette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Quiet text button, e.g. "Skip".
struct SecondaryButton: View {
    @Environment(\.palette) private var palette
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .foregroundStyle(palette.sageDark)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
