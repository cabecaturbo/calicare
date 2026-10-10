import Core
import SwiftUI

/// Info › Supplements: "What does the plan say to give, and when?" Giving now
/// (with times), not giving yet (one action each), and what the provider only
/// mentioned.
struct SupplementsScreen: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        let plan = model.supplementPlan
        let giving = plan.rows.filter { $0.item.isGiving == true }
        let notYet = plan.rows.filter { $0.item.isGiving != true }
        PlanPage(title: "Supplements") {
            if plan.rows.isEmpty && plan.mentioned.isEmpty {
                Text("Your plan has no supplements.").textStyle(.body).foregroundStyle(palette.graphite)
            }
            if !giving.isEmpty {
                Group(title: "Giving now") {
                    ForEach(giving) { GivingRow(row: $0) }
                }
            }
            if !notYet.isEmpty {
                Group(title: "Not giving yet") {
                    ForEach(notYet) { row in
                        AdaptiveStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(SupplementDisplay(row.item).name).textStyle(.body).foregroundStyle(palette.ink)
                                if let dose = row.item.dose { Text(dose).textStyle(.meta).foregroundStyle(palette.graphite) }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button("Add to To do") { Task { await setGiving(row.item, true) } }
                                .buttonStyle(.textLink)
                        }
                        .frame(minHeight: 50)
                        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    }
                }
            }
            if !plan.rules.isEmpty {
                Group(title: "Your plan's rules") {
                    ForEach(plan.rules, id: \.self) { Text("“\($0)”").textStyle(.body).foregroundStyle(palette.graphite) }
                }
            }
            if !plan.mentioned.isEmpty {
                Group(title: "Your provider mentioned") {
                    ForEach(plan.mentioned) { Text("“\($0.providerWords)”").textStyle(.meta).foregroundStyle(palette.graphite) }
                }
            }
        }
    }

    private func setGiving(_ item: PlanItemInfo, _ on: Bool) async {
        try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).setGiving(item.id, on)
        await model.load()
        await LogChanges.didChange()
    }
}

/// A supplement being given: name, dose, its times, how to give it, and stop.
private struct GivingRow: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let row: SupplementPlan.Row
    @State private var showingHow = false

    var body: some View {
        let display = SupplementDisplay(row.item)
        VStack(alignment: .leading, spacing: Spacing.x2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(display.name).textStyle(.body).foregroundStyle(palette.ink)
                if let meta = display.meta { Text(meta).textStyle(.meta).foregroundStyle(palette.graphite) }
            }
            .fixedSize(horizontal: false, vertical: true)
            AdaptiveStack(spacing: Spacing.x2) {
                ForEach(TodoBlock.allCases, id: \.self) { block in
                    let on = row.item.blocks.contains(block)
                    Button { Task { await toggle(block) } } label: {
                        Text(block.title)
                            .textStyle(.meta)
                            .foregroundStyle(on ? palette.paper : palette.ink)
                            .padding(.horizontal, Spacing.x2 + Spacing.x1)
                            .padding(.vertical, Spacing.x1)
                            .background(Capsule().fill(on ? palette.accent : Color.clear))
                            .overlay(Capsule().strokeBorder(on ? palette.accent : palette.hairline, lineWidth: 1))
                            .frame(minHeight: Size.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(block.title)
                    .accessibilityValue(on ? "Given then" : "Not then")
                }
            }
            if !display.howToGive.isEmpty {
                Button { showingHow.toggle() } label: {
                    HStack(spacing: Spacing.x1) {
                        Text("How to give").textStyle(.meta)
                        Image(systemName: showingHow ? "chevron.up" : "chevron.down").font(.caption)
                    }
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: Size.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showingHow {
                    ForEach(display.howToGive, id: \.self) {
                        Text("“\($0)”").textStyle(.meta).foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button("Stop giving") { Task { await stop() } }
                .buttonStyle(.textLink)
        }
        .padding(.vertical, Spacing.x2)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }

    private func toggle(_ block: TodoBlock) async {
        var blocks = Set(row.item.blocks)
        if blocks.contains(block) { blocks.remove(block) } else { blocks.insert(block) }
        guard !blocks.isEmpty else { return }
        try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).setGivingTimes(row.item.id, Array(blocks))
        await model.load()
        await LogChanges.didChange()
    }

    private func stop() async {
        try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).setGiving(row.item.id, false)
        await model.load()
        await LogChanges.didChange()
    }
}

/// A titled group on an Info screen.
private struct Group<Content: View>: View {
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
