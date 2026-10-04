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
        HStack(spacing: Spacing.x4) {
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
        .padding(.horizontal, Spacing.x4)
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

/// The name, one big statement, one line, and what we promise.
private struct WelcomeStep: View {
    @Environment(\.palette) private var palette
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                BigStatement(text: "Log itchy nights in one tap.", line: "Keep your child’s care plan in one place.")
                    .padding(.top, 120)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.margin)
        } footer: {
            Text("No ads. Photos stay on your phone. Not medical advice.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Start", action: onContinue)
                .buttonStyle(.primary)
        }
    }
}

/// "Cali Care" in Newsreader, small. No symbol.
struct Wordmark: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Text("Cali Care")
            .textStyle(.title)
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)
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
            OnboardingHeading(title: "Who are we caring for?", detail: "Their first name is enough.")
            ChildDetailsForm(details: $details, nameOnly: true) {
                if details.canSave { onContinue() }
            }
            Text("It stays on this phone. You can add a birthday later.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
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

/// The big statement and one line, with the margin, for the steps after Welcome.
struct OnboardingHeading: View {
    let title: String
    let detail: String

    var body: some View {
        BigStatement(text: title, line: detail)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.x6)
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
            .padding(.top, Spacing.x6)
            .padding(.bottom, Spacing.margin)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.x2) {
                footer
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x4)
            .padding(.bottom, Spacing.x2)
            .paperBackground()
        }
    }
}
