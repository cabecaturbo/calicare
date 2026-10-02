import Core
import SwiftUI

/// "Log a meal": tap foods from the safe (and testing) list, then Log.
struct MealSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var picked: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x4) {
                    let foods = model.foods.filter { $0.status != .paused }.map(\.name)
                    if foods.isEmpty {
                        Text("Add safe foods to the food list first.").textStyle(.body).foregroundStyle(palette.graphite)
                    }
                    FlowChips(items: foods, picked: $picked)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
            .paperBackground(.oat)
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        let names = picked.sorted()
                        dismiss()
                        Task { await model.logMeal(names) }
                    }
                    .disabled(picked.isEmpty)
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium, .large])
    }
}

/// Tappable food names that wrap onto new lines.
private struct FlowChips: View {
    @Environment(\.palette) private var palette
    let items: [String]
    @Binding var picked: Set<String>

    var body: some View {
        WrapLayout(spacing: Spacing.x2) {
            ForEach(items, id: \.self) { item in
                let on = picked.contains(item)
                Button {
                    if on { picked.remove(item) } else { picked.insert(item) }
                } label: {
                    Text(item)
                        .textStyle(.body)
                        .foregroundStyle(on ? palette.paper : palette.ink)
                        .padding(.horizontal, Spacing.x3)
                        .frame(minHeight: Size.touchTarget)
                        .background(on ? palette.indigo : palette.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? palette.indigo : palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Lays children out in rows, wrapping when a row is full.
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The rotation, every day: the plan's length, safe foods by family.
struct RotationView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let days: Int

    var body: some View {
        let plan = FoodRotation.plan(foods: model.foods, days: days)
        let today = FoodRotation.today(start: model.activePlan?.startedAt ?? .now, days: days, now: .now)
        List {
            ForEach(Array(plan.enumerated()), id: \.offset) { index, families in
                Section {
                    if families.isEmpty {
                        Text("No safe foods here yet").textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                    ForEach(families, id: \.family) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.foods.joined(separator: ", ")).textStyle(.body).foregroundStyle(palette.ink)
                            Text(entry.family).textStyle(.meta).foregroundStyle(palette.graphite)
                        }
                    }
                } header: {
                    Text(index == today ? "Day \(index + 1) · today" : "Day \(index + 1)")
                        .textStyle(.section)
                        .foregroundStyle(index == today ? palette.indigo : palette.ink)
                        .textCase(nil)
                }
                .listRowBackground(palette.paper)
            }
            Section {
                Text("Your plan's \(days)-day rotation, using only foods on your safe list. Each family comes around once every \(days) days.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("Rotation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
