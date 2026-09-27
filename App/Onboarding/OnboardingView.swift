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
        .paperBackground()
        .task { await loadChildName() }
    }

    private var progress: some View {
        HStack(spacing: Spacing.x1) {
            ForEach(Step.allCases, id: \.self) { item in
                Rectangle()
                    .fill(item.rawValue <= step.rawValue ? palette.indigo : palette.hairline)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x4)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private func go(to next: Step) {
        withAnimation(.easeOut(duration: 0.3)) { step = next }
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

/// Screen 1: the wordmark and what the app does, in one warm sentence.
private struct WelcomeStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                Text("A calm place to follow your child's care plan and log how their skin and nights are going, in one tap.")
                    .textStyle(.lede)
                    .foregroundStyle(palette.ink)
                    .padding(.top, Spacing.ledeToSection)
                Text("No account needed. Everything stays on this phone.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .padding(.top, Spacing.x4)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.margin)
        } footer: {
            Button("Add your child", action: onContinue)
                .buttonStyle(.primary)
        }
    }
}

/// "Cali Care" set in Newsreader Display over a hairline ink rule. No symbol.
struct Wordmark: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text("Cali Care")
                .textStyle(.display)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            palette.ink.frame(height: Rule.width)
                .accessibilityHidden(true)
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
            VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                Text("Who are you caring for?")
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("A first name or nickname is enough.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.ledeToSection)

            ChildDetailsForm(details: $details) {
                if details.canSave { onContinue() }
            }
            if let error {
                Text(error)
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x4)
            }
        } footer: {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .disabled(!details.canSave)
        }
    }
}

/// Scrolling content with pinned buttons, so nothing clips at large text sizes.
/// Content runs full width; text blocks add the 24pt margin themselves so
/// ledger rows can reach the edges.
struct OnboardingPage<Content: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.section)
            .padding(.bottom, Spacing.margin)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.x2) {
                footer
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x3)
            .padding(.bottom, Spacing.x2)
            .paperBackground()
        }
    }
}
