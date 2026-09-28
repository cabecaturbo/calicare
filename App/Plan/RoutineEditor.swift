import Core
import SwiftUI

/// "Edit routine": the parent's own steps, morning and evening. Add, rename,
/// reorder, pause, delete. Nothing is suggested; steps are whatever they type.
struct RoutineEditor: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var steps: [RoutineStepInfo] = []
    @State private var drafts: [RoutineTime: String] = [:]
    @State private var renaming: RoutineStepInfo?
    @State private var newName = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(RoutineTime.allCases, id: \.self) { time in
                    section(time)
                }
            }
            .settingsListStyle(palette)
            .paperBackground(.oat)
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename step", isPresented: renameShowing) {
                TextField("Step", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let step = renaming { run { try await $0.rename(step.id, to: newName) } }
                }
            }
            .alert(problem ?? "", isPresented: problemShowing) {
                Button("OK", role: .cancel) {}
            }
        }
        .tint(palette.indigo)
        .task { await reload() }
    }

    private func section(_ time: RoutineTime) -> some View {
        let list = steps.filter { $0.time == time }
        return Section {
            ForEach(list) { step in
                HStack {
                    Text(step.name)
                        .textStyle(.body)
                        .foregroundStyle(step.isActive ? palette.ink : palette.graphite)
                    Spacer()
                    if !step.isActive {
                        Text("Paused")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    newName = step.name
                    renaming = step
                }
                .listRowBackground(palette.paper)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Rename")
                .swipeActions(edge: .trailing) {
                    Button("Delete") { run { try await $0.delete(step.id) } }
                        .tint(palette.graphite)
                    Button(step.isActive ? "Pause" : "Resume") { run { try await $0.setActive(step.id, !step.isActive) } }
                        .tint(palette.indigo)
                }
                .accessibilityActions {
                    Button(step.isActive ? "Pause" : "Resume") { run { try await $0.setActive(step.id, !step.isActive) } }
                    Button("Delete") { run { try await $0.delete(step.id) } }
                }
            }
            .onMove { from, to in
                var ids = list.map(\.id)
                ids.move(fromOffsets: from, toOffset: to)
                run { [child = model.child] in
                    guard let child else { return }
                    try await $0.reorder(child: child.id, time: time, ids: ids)
                }
            }

            TextField("Add a step", text: Binding(get: { drafts[time] ?? "" }, set: { drafts[time] = $0 }))
                .textStyle(.body)
                .submitLabel(.done)
                .onSubmit { add(time) }
                .listRowBackground(palette.paper)
                .accessibilityLabel(time == .morning ? "Add a morning step" : "Add an evening step")
        } header: {
            Text(time == .morning ? "Morning" : "Evening")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
        } footer: {
            if time == .evening {
                Text("Tap a step to rename it. Swipe left to pause or delete. Touch and hold to move it. Paused steps keep their history.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
        }
    }

    private func add(_ time: RoutineTime) {
        let name = (drafts[time] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let child = model.child else { return }
        drafts[time] = ""
        run { try await $0.add(name: name, time: time, child: child.id) }
    }

    /// Runs one change, then reloads the list.
    private func run(_ change: @escaping (RoutineStore) async throws -> Void) {
        Task {
            do {
                try await change(RoutineStore(modelContainer: try CaliCareModelContainer.shared()))
                await reload()
                await LogChanges.didChange()
            } catch {
                problem = "Couldn't save that change. Please try again."
            }
        }
    }

    private func reload() async {
        guard let child = model.child,
              let store = try? RoutineStore(modelContainer: CaliCareModelContainer.shared()),
              let loaded = try? await store.steps(child: child.id, includeInactive: true)
        else { return }
        steps = loaded
    }

    private var renameShowing: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var problemShowing: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }
}
