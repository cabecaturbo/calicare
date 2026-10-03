import Core
import SwiftUI

/// One To do item, opened from its label: what to do in plain words, then the
/// provider's exact words, never cut or rewritten.
struct TodoItemSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let item: TodoDay.Item

    var body: some View {
        switch item.kind {
        case .step(let step) where step.planItemID == nil:
            // The parent's own step: their words, and renaming it.
            StepSourceSheet(step: step)
        default:
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.x7) {
                        content
                    }
                    .padding(.horizontal, Spacing.margin)
                    .padding(.vertical, Spacing.x5)
                }
                .paperBackground(.oat)
                .solidNavigationBar()
                .navigationTitle(item.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .tint(palette.indigo)
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .skin:
            let steps = model.todo?.skin?.steps ?? []
            Section(title: "What to do") {
                Paragraph(howOftenSkin)
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    let plan = step.planItemID.flatMap { model.planItems[$0] }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1)  \(step.displayName)").textStyle(.body).foregroundStyle(palette.ink)
                        if let plain = plan?.plainText {
                            Text(plain).textStyle(.meta).foregroundStyle(palette.graphite)
                        }
                    }
                }
            }
            Section(title: "Your provider's words") {
                ForEach(steps) { step in
                    ProviderWords(step.planItemID.flatMap { model.planItems[$0]?.providerWords } ?? step.original)
                }
            }
        case .supplement(let plan):
            Section(title: "What to do") {
                Paragraph(giveLine(plan))
                if let plain = plan.plainText { Paragraph(plain) }
            }
            Section(title: "Your provider's words") {
                ProviderWords(plan.providerWords)
                ForEach([plan.timing, plan.duration].compactMap { $0 }, id: \.self) { ProviderWords($0) }
            }
        case .step(let step):
            let plan = step.planItemID.flatMap { model.planItems[$0] }
            Section(title: "What to do") {
                Paragraph(plan?.plainText ?? step.displayName)
            }
            Section(title: "Your provider's words") {
                ProviderWords(plan?.providerWords ?? step.original)
            }
        }
    }

    /// "Do it 3-4 times a day." from the plan's count.
    private var howOftenSkin: String {
        guard let target = model.todo?.skin?.target else { return "Do these in order." }
        let count = target.lowerBound == target.upperBound ? "\(target.lowerBound)" : "\(target.lowerBound)-\(target.upperBound)"
        return "Do these in order, \(count) times a day."
    }

    /// "Give 8 drops each time." and "When: Morning, Bedtime."
    private func giveLine(_ plan: PlanItemInfo) -> String {
        let when = "When: " + plan.blocks.map(\.title).joined(separator: ", ") + "."
        return plan.dose.map { "Give \($0) each time. \(when)" } ?? when
    }
}

/// A sheet section: a serif header and its lines.
private struct Section<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(title).textStyle(.section).foregroundStyle(palette.ink).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

private struct Paragraph: View {
    @Environment(\.palette) private var palette
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).textStyle(.body).foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
    }
}

/// The provider's words as written, in quotes, selectable.
private struct ProviderWords: View {
    @Environment(\.palette) private var palette
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text("“\(text)”")
            .textStyle(.body)
            .foregroundStyle(palette.graphite)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
