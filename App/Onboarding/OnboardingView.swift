import Core
import SwiftUI

/// Full screen, no account: Welcome → Your child → Reminders → Log from anywhere → Today.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, child, reminders, logAnywhere
    }

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step
    @State private var forward = true
    @State private var details = ChildDetails()
    /// Set once the child is saved, so going back edits instead of adding twice.
    @State private var child: ChildInfo?
    @State private var saveError: String?
    @State private var saving = false
    let onFinish: () -> Void

    init(start: Step = .welcome, onFinish: @escaping () -> Void) {
        _step = State(initialValue: start)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome { topBar }
            Group {
                switch step {
                case .welcome:
                    WelcomeStep { go(to: .child) }
                case .child:
                    ChildStep(details: $details, error: saveError) { Task { await saveChild() } }
                case .reminders:
                    RemindersStep(childName: child?.name) { go(to: .logAnywhere) }
                case .logAnywhere:
                    LogAnywhereStep(onFinish: onFinish)
                }
            }
            .id(step)
            .transition(transition)
        }
        .paperBackground()
        .task { await loadChild() }
    }

    /// Back, and a thin progress line for the three steps after Welcome.
    private var topBar: some View {
        HStack(spacing: Spacing.x3) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { go(to: previous) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: Size.touchTarget, height: Size.touchTarget)
            }
            .accessibilityLabel("Back")
            HStack(spacing: Spacing.x1) {
                ForEach(Step.allCases.dropFirst(), id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? palette.indigo : palette.hairline)
                        .frame(height: 2)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue) of \(Step.allCases.count - 1)")
            Color.clear.frame(width: Size.touchTarget, height: 1)
        }
        .padding(.horizontal, Spacing.x3)
        .padding(.top, Spacing.x2)
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func go(to next: Step) {
        forward = next.rawValue > step.rawValue
        withAnimation(.easeOut(duration: 0.3)) { step = next }
    }

    private func saveChild() async {
        guard details.canSave, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            child = try await details.save(updating: child?.id)
            saveError = nil
            go(to: .reminders)
        } catch {
            saveError = "Couldn't save that just now. Please try again."
        }
    }

    /// Someone who left mid-setup picks up with their child already there.
    private func loadChild() async {
        guard child == nil,
              let saved = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).currentChild()
        else { return }
        child = saved
        details = ChildDetails(saved)
    }
}

/// The wordmark, the sunrise drawing, one sentence, and what we promise.
private struct WelcomeStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                Illustration(kind: .sun, size: CGSize(width: 168, height: 160))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.section)
                Text("A calm place to follow your child’s care plan and log how their skin and nights are going, in one tap.")
                    .textStyle(.lede)
                    .foregroundStyle(palette.ink)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.margin)
        } footer: {
            Button("Add your child", action: onContinue)
                .buttonStyle(.primary)
            Text("No ads. Photos never leave your phone.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
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

/// A first name is all we need.
private struct ChildStep: View {
    @Environment(\.palette) private var palette
    @Binding var details: ChildDetails
    let error: String?
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            OnboardingHeading(title: "Who are we looking after?", detail: "A first name or nickname is enough.")
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

/// Title and one line, with the margin, for the steps after Welcome.
struct OnboardingHeading: View {
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
                .foregroundStyle(palette.graphite)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.ledeToSection)
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
