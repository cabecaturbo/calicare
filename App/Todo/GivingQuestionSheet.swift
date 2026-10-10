import Core
import SwiftUI

/// Asked once per plan: "Which of these are you giving now?" Checked ones go
/// on To do; the rest wait in Info › Supplements under "Not giving yet."
struct GivingQuestionSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var giving: Set<UUID> = []
    @State private var loaded = false

    /// Supplements the parent hasn't said yes or no to yet.
    static func unanswered(_ items: [PlanItemInfo], logs: [LogEntry]) -> [SupplementPlan.Row] {
        SupplementPlan(items: items, logs: logs, now: .now).rows.filter { $0.item.isGiving == nil }
    }

    private var rows: [SupplementPlan.Row] { Self.unanswered(Array(model.planItems.values), logs: model.supplementLogs) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows) { row in
                        let isOn = giving.contains(row.item.id)
                        Button {
                            if isOn { giving.remove(row.item.id) } else { giving.insert(row.item.id) }
                        } label: {
                            HStack(spacing: Spacing.x4) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isOn ? palette.accent : palette.graphite)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(SupplementDisplay(row.item).name).textStyle(.body).foregroundStyle(palette.ink)
                                    if let dose = row.item.dose {
                                        Text(dose).textStyle(.meta).foregroundStyle(palette.graphite)
                                    }
                                }
                            }
                            .frame(minHeight: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(palette.paper)
                        .accessibilityValue(isOn ? "Giving now" : "Not yet")
                    }
                } header: {
                    FormHeader("Which of these are you giving now?")
                } footer: {
                    Text("Only these go on To do. You can change this any time in Info, Supplements.")
                        .textStyle(.meta)
                }
            }
            .settingsListStyle(palette)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
        }
        .tint(palette.accent)
        .interactiveDismissDisabled()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            // Anything already started is checked.
            giving = Set(rows.filter(\.isActive).map(\.item.id))
        }
    }

    private func save() async {
        guard let container = try? CaliCareModelContainer.shared() else { return }
        let plans = CarePlanStore(modelContainer: container)
        for row in rows { try? await plans.setGiving(row.item.id, giving.contains(row.item.id)) }
        await LogChanges.didChange()
        dismiss()
    }
}
