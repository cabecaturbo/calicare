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
                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x2)
                    .padding(.bottom, Spacing.x7)
                }
                .paperBackground(.oat)
                .navigationTitle(item.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .tint(palette.indigo)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Canvas "To do v2, one step": the big statement and its line, the steps
    /// numbered, then the provider's words.
    @ViewBuilder private var content: some View {
        switch item.kind {
        case .skin:
            let steps = model.todo?.skin?.steps ?? []
            Statement(howOftenSkin, line: "Do these in order each time.")
            VStack(alignment: .leading, spacing: Spacing.x3) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    let plan = step.planItemID.flatMap { model.planItems[$0] }
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
                        Text("\(index + 1)").textStyle(.body).fontWeight(.semibold).foregroundStyle(palette.ink)
                            .frame(minWidth: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.displayName).textStyle(.body).foregroundStyle(palette.ink)
                            if let plain = plan?.plainText {
                                Text(plain).textStyle(.meta).foregroundStyle(palette.graphite)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, Spacing.x5)
            Words {
                ForEach(steps) { step in
                    ProviderWords(step.planItemID.flatMap { model.planItems[$0]?.providerWords } ?? step.original)
                }
            }
        case .supplement(let plan):
            Statement(plan.dose.map { "Give \($0)." } ?? "\(item.label).", line: whenLine(plan))
            if let plain = plan.plainText {
                Paragraph(plain).padding(.top, Spacing.x5)
            }
            Words {
                ProviderWords(plan.providerWords)
                ForEach([plan.timing, plan.duration].compactMap { $0 }, id: \.self) { ProviderWords($0) }
            }
        case .step(let step):
            let plan = step.planItemID.flatMap { model.planItems[$0] }
            Statement("\(item.label).", line: plan?.plainText)
            Words {
                ProviderWords(plan?.providerWords ?? step.original)
            }
        }
    }

    /// "3 to 4 times a day." from the plan's count.
    private var howOftenSkin: String {
        guard let target = model.todo?.skin?.target else { return "As often as the plan says." }
        if target.lowerBound == target.upperBound {
            switch target.lowerBound {
            case 1: return "Once a day."
            case 2: return "Twice a day."
            default: return "\(target.lowerBound) times a day."
            }
        }
        return "\(target.lowerBound) to \(target.upperBound) times a day."
    }

    /// "Morning and bedtime."
    private func whenLine(_ plan: PlanItemInfo) -> String? {
        let names = plan.blocks.map(\.title)
        guard let first = names.first else { return nil }
        let rest = names.dropFirst().map { $0.lowercased() }
        switch rest.count {
        case 0: return "\(first)."
        case 1: return "\(first) and \(rest[0])."
        default: return "\(first), " + rest.dropLast().joined(separator: ", ") + ", and \(rest.last!)."
        }
    }
}

/// The one big statement and its line.
private struct Statement: View {
    @Environment(\.palette) private var palette
    let text: String
    let line: String?
    init(_ text: String, line: String?) {
        self.text = text
        self.line = line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(text)
                .textStyle(.statement)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let line {
                Text(line).textStyle(.body).foregroundStyle(palette.graphite).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Spacing.x5)
    }
}

/// "Your provider's words" and the plan's own lines, never cut.
private struct Words<Content: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Your provider's words").textStyle(.label).foregroundStyle(palette.ink).accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.top, Spacing.x6)
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
