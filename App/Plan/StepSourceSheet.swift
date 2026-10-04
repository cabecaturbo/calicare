import Core
import SwiftUI

/// A step's original words from the plan, and its name on Plan, which the
/// parent can change. The original words never change.
struct StepSourceSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let step: RoutineStepInfo
    @State private var name: String
    @State private var problem: String?

    init(step: RoutineStepInfo) {
        self.step = step
        _name = State(initialValue: step.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, axis: .vertical)
                        .textStyle(.body)
                } header: {
                    Text("Name on Plan").textStyle(.section).foregroundStyle(palette.ink).textCase(nil)
                } footer: {
                    Text("Start with what to do: “Apply aloe vera”.").textStyle(.meta)
                }
                Section {
                    Text(step.original)
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .textSelection(.enabled)
                    if let category = step.category {
                        Label(category.title, systemImage: category.symbol)
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                } header: {
                    Text(step.planItemID == nil ? "Your words" : "From your plan")
                        .textStyle(.section).foregroundStyle(palette.ink).textCase(nil)
                }
                if let problem {
                    Text(problem).textStyle(.meta)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle(step.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines) != step.displayName else {
            dismiss()
            return
        }
        do {
            try await RoutineStore(modelContainer: CaliCareModelContainer.shared()).rename(step.id, to: name)
            await LogChanges.didChange()
            dismiss()
        } catch RoutineStoreError.emptyName {
            problem = "A step needs a name."
        } catch {
            problem = "Couldn’t save that. Please try again."
        }
    }
}
