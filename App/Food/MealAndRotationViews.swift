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
                    FoodChips(items: model.foods.filter { $0.status != .paused }.map(\.name), picked: $picked)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
            .paperBackground(.oat)
            .solidNavigationBar()
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
        .solidNavigationBar(.paper)
        .navigationTitle("Rotation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
