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
    @State private var problem: String?
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    var body: some View {
        NavigationStack {
            List {
                ForEach(RoutineTime.allCases, id: \.self) { time in
                    section(time)
                }
            }
            .settingsListStyle(palette)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle("Change the list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $renaming, onDismiss: { Task { await reload() } }) { step in
                StepSourceSheet(step: step)
                    .nightAwarePalette()
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
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                    Image(systemName: step.category?.symbol ?? "circle")
                        .font(.body)
                        .foregroundStyle(step.category == nil ? .clear : palette.graphite)
                        .frame(minWidth: iconWidth)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.kind == .note ? StepLabeler.clean(step.original) : step.displayName)
                            .textStyle(.body)
                            .foregroundStyle(step.isActive && step.kind == .task ? palette.ink : palette.graphite)
                        if let meta = meta(step) {
                            Text(meta)
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { renaming = step }
                .listRowBackground(palette.paper)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Shows the plan's words and lets you rename it.")
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
            FormHeader(time == .morning ? "Morning" : "Evening")
        } footer: {
            if time == .evening {
                Text("Tap a step to see the plan's words or rename it. Swipe left to pause or delete. Touch and hold to move it. Paused steps keep their history.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
        }
    }

    /// "Paused", "Note · not ticked off", or the original words when the label differs.
    private func meta(_ step: RoutineStepInfo) -> String? {
        if !step.isActive { return "Paused" }
        if step.kind == .note { return "Note · not ticked off" }
        let original = StepLabeler.clean(step.original)
        // "Moisturizer" under "Apply moisturizer" says nothing new.
        return step.displayName.localizedCaseInsensitiveContains(original) ? nil : original
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

    private var problemShowing: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }
}
