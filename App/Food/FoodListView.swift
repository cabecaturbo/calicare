import Core
import SwiftUI

/// Plan › Food list: safe, testing, and paused foods, each with its family and
/// who decided. The app never moves a food; the parent (or the plan) does.
struct FoodListView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var newName = ""
    @State private var newStatus: FoodStatus = .safe
    @State private var editing: FoodInfo?
    @State private var problem: String?
    @State private var loggingMeal = false
    @State private var askingIdeas = false
    @State private var addingBatch = false
    @State private var freezing: LeftoverBatch?
    @State private var freezerDays = 30

    var body: some View {
        List {
            Section {
                FoodCounts(foods: model.foods)
                    .listRowBackground(palette.paper)
            }
            if Features.foodExtras {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(model.plantsThisWeek) plant\(model.plantsThisWeek == 1 ? "" : "s") this week")
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                        if let goal = model.plantGoal {
                            Text("Your plan's goal: \(goal.lowerBound == goal.upperBound ? "\(goal.lowerBound)" : "\(goal.lowerBound)–\(goal.upperBound)")")
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                    }
                    Spacer()
                    Button("Log a meal") { loggingMeal = true }
                        .buttonStyle(.textLink)
                }
                Button("What can I make") { askingIdeas = true }
                    .buttonStyle(.textLink)
                if let days = model.rotationDays {
                    NavigationLink {
                        RotationView(days: days)
                    } label: {
                        Text("Rotation · \(days) days").textStyle(.body).foregroundStyle(palette.ink)
                    }
                }
            }
            .listRowBackground(palette.paper)
            }
            let avoid = PlanFoods.avoidedLines(in: Array(model.planItems.values).sorted { $0.order < $1.order })
            if !avoid.isEmpty {
                Section {
                    ForEach(Array(avoid.enumerated()), id: \.element.id) { index, line in
                        // The qualifier shows once, under the last line it belongs to.
                        let next = index + 1 < avoid.count ? avoid[index + 1] : nil
                        let showsNote = line.qualifier != nil && next?.qualifier != line.qualifier
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.name).textStyle(.body).foregroundStyle(palette.ink)
                            if showsNote, let note = line.qualifier {
                                Text(note.prefix(1).uppercased() + note.dropFirst()).textStyle(.meta).foregroundStyle(palette.graphite)
                            }
                        }
                        .listRowBackground(palette.paper)
                    }
                    if !fromPlan.isEmpty {
                        Button("Add them as paused") { Task { await addFromPlan() } }
                            .buttonStyle(.textLink)
                            .listRowBackground(palette.paper)
                    }
                } header: {
                    FormHeader("Your plan says to avoid")
                }
            }
            let running = model.foodTrials.filter(\.isRunning)
            if !running.isEmpty {
                Section {
                    ForEach(running) { trial in
                        NavigationLink {
                            FoodTrialView(foodID: trial.food.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trial.food.name).textStyle(.body).foregroundStyle(palette.ink)
                                let day = trial.day(at: .now)
                                Text([day <= trial.days ? "Day \(day) of \(trial.days)" : "Trial days done",
                                      trial.step(at: .now).map { "today \($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .textStyle(.meta)
                                    .foregroundStyle(palette.graphite)
                            }
                        }
                        .listRowBackground(palette.paper)
                    }
                } header: {
                    FormHeader("Trials")
                }
            }
            Section {
                HStack {
                    TextField("Add a food", text: $newName)
                        .textStyle(.body)
                        .submitLabel(.done)
                        .onSubmit { Task { await add() } }
                    Picker("Status", selection: $newStatus) {
                        ForEach(FoodStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                }
                .listRowBackground(palette.paper)
                if let problem {
                    Text(problem).textStyle(.meta).foregroundStyle(palette.graphite).listRowBackground(palette.paper)
                }
            }
            ForEach(FoodStatus.allCases, id: \.self) { status in
                let group = model.foods.filter { $0.status == status }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { food in
                            Button { editing = food } label: { row(food) }
                                .buttonStyle(.plain)
                                .listRowBackground(palette.paper)
                        }
                    } header: {
                        FormHeader("\(status.title) · \(group.count)")
                    } footer: {
                        if status == .paused, let line = NutrientCoverage.sentence(paused: group.map(\.name)) {
                            Text(line).textStyle(.meta).foregroundStyle(palette.graphite)
                        }
                    }
                }
            }
            if Features.foodExtras {
                LeftoversSection(onAdd: { addingBatch = true }, onFreeze: { freezing = $0 })
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle("Food list")
        .navigationBarTitleDisplayMode(.inline)
        .tint(palette.indigo)
        .sheet(isPresented: $addingBatch) {
            AddBatchSheet().nightAwarePalette()
        }
        .alert("Freeze \(freezing?.name ?? "")", isPresented: Binding(get: { freezing != nil }, set: { if !$0 { freezing = nil } })) {
            TextField("Days", value: $freezerDays, format: .number).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Freeze") {
                if let batch = freezing { Task { await model.freezeBatch(batch, days: max(freezerDays, 1)) } }
            }
        } message: {
            Text("How many days to keep it in the freezer?")
        }
        .sheet(isPresented: $askingIdeas) {
            MealIdeasSheet()
                .nightAwarePalette()
        }
        .sheet(isPresented: $loggingMeal) {
            MealSheet()
                .nightAwarePalette()
        }
        .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { food in
            FoodEditor(food: food)
                .nightAwarePalette()
        }
    }

    /// Foods the plan says to avoid that aren't on the list yet.
    private var fromPlan: [String] {
        PlanFoods.avoided(in: Array(model.planItems.values)).filter { name in
            !model.foods.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
    }

    private func row(_ food: FoodInfo) -> some View {
        AdaptiveStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).textStyle(.body).foregroundStyle(palette.ink)
                if let family = food.family {
                    Text(family).textStyle(.meta).foregroundStyle(palette.graphite)
                }
            }
            Spacer(minLength: 0)
            Text("\(food.decidedBy == .plan ? "Plan" : "You") · \(food.statusChangedAt.formatted(.dateTime.month(.abbreviated).day()))")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
        .contentShape(Rectangle())
    }

    private var store: FoodStore? {
        (try? CaliCareModelContainer.shared()).map { FoodStore(modelContainer: $0) }
    }

    private func add() async {
        guard let child = model.child, !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await store?.add(name: newName, status: newStatus, decidedBy: .parent, child: child.id)
            newName = ""
            problem = nil
            await model.load()
            Task { await LogChanges.didChange() }
        } catch FoodStoreError.duplicate {
            problem = "That food is already on the list."
        } catch {
            problem = "Couldn't add that. Please try again."
        }
    }

    private func addFromPlan() async {
        guard let child = model.child else { return }
        for name in fromPlan {
            _ = try? await store?.add(name: name, status: .paused, decidedBy: .plan, child: child.id)
        }
        await model.load()
        Task { await LogChanges.didChange() }
    }
}

/// The food list's focal point: how many safe foods, then testing and paused.
private struct FoodCounts: View {
    @Environment(\.palette) private var palette
    let foods: [FoodInfo]

    var body: some View {
        let safe = foods.filter { $0.status == .safe }.count
        let others = [FoodStatus.testing, .paused].compactMap { status -> String? in
            let count = foods.filter { $0.status == status }.count
            return count > 0 ? "\(count) \(status.title.lowercased())" : nil
        }
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(foods.isEmpty ? "No foods yet" : "\(safe) safe food\(safe == 1 ? "" : "s")")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
            Text(foods.isEmpty ? "Add what's safe, being tested, or paused." : (others.isEmpty ? "Nothing testing or paused" : others.joined(separator: " · ")))
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
        .padding(.vertical, Spacing.x2)
        .accessibilityElement(children: .combine)
    }
}

/// One food: its status (and who decided), its family, a note, or remove it.
private struct FoodEditor: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let food: FoodInfo
    @State private var status: FoodStatus
    @State private var family: String
    @State private var note: String
    @State private var startingTrial = false

    init(food: FoodInfo) {
        self.food = food
        _status = State(initialValue: food.status)
        _family = State(initialValue: food.family ?? "")
        _note = State(initialValue: food.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Status", selection: $status) {
                        ForEach(FoodStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("\(food.status.title) since \(food.statusChangedAt.formatted(date: .abbreviated, time: .omitted)), decided by \(food.decidedBy == .plan ? "the plan" : "you").")
                }
                Section("Family") {
                    Picker("Family", selection: $family) {
                        Text("None").tag("")
                        ForEach(families, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                }
                Section {
                    Button("Start a trial") { startingTrial = true }
                    Button("Remove from the list") { Task { await remove() } }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
        }
        .tint(palette.indigo)
        .sheet(isPresented: $startingTrial, onDismiss: { dismiss() }) {
            StartTrialSheet(food: food)
                .nightAwarePalette()
        }
    }

    private var families: [String] {
        Array(Set(FoodFamilies.names + [food.family].compactMap { $0 })).sorted()
    }

    private func save() async {
        guard let store = try? FoodStore(modelContainer: CaliCareModelContainer.shared()) else { return }
        if status != food.status { try? await store.setStatus(food.id, status, decidedBy: .parent) }
        if family != (food.family ?? "") { try? await store.setFamily(food.id, family) }
        if note != (food.note ?? "") { try? await store.setNote(food.id, note) }
        await LogChanges.didChange()
        dismiss()
    }

    private func remove() async {
        try? await FoodStore(modelContainer: CaliCareModelContainer.shared()).delete(food.id)
        await LogChanges.didChange()
        dismiss()
    }
}
