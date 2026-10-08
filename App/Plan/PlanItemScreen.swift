import Core
import SwiftUI

/// Plan › one item (canvas "Plan item detail"): its name, where it stands,
/// one button to start or stop it, which times, and the provider's whole
/// words. Notes, baths, food, and home show only the words.
struct PlanItemScreen: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var addingStep = false
    /// The times "Start" will use, before it's in the daily list.
    @State private var chosen: Set<TodoBlock>?
    @State private var confirmingStop = false
    @State private var working = false

    var body: some View {
        ScrollView {
            if let entry = model.planEntries.entry(id) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.label)
                        .textStyle(.display)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let status = PlanWords.status(entry.status) ?? entry.meta {
                        Text(status)
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                            .padding(.top, Spacing.x2)
                    }
                    if entry.kind != .reading {
                        action(entry).padding(.top, Spacing.x5)
                        times(entry).padding(.top, Spacing.x6)
                    }
                    if entry.kind == .supplement {
                        doseSteps(entry).padding(.top, Spacing.x6)
                    }
                    words(entry).padding(.top, Spacing.x6)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
                .padding(.bottom, BottomBar.clearance)
                .confirmationDialog(stopTitle(entry), isPresented: $confirmingStop, titleVisibility: .visible) {
                    Button(stopButton(entry), role: .destructive) { Task { await stop(entry) } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Its history stays.")
                }
            }
        }
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Plan", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .tint(palette.accent)
            }
        }
        .sheet(isPresented: $addingStep) {
            if let entry = model.planEntries.entry(id) {
                DoseStepSheet { amount, date in
                    Task { await change { try await $0.addDoseStep(entry, amount: amount, from: date) } }
                }
                .nightAwarePalette()
            }
        }
    }

    // MARK: - Start or stop

    private func action(_ entry: PlanEntries.Entry) -> some View {
        let isSupplement = entry.kind == .supplement
        let title = entry.isActive
            ? (isSupplement ? "Stop giving it" : "Remove from daily list")
            : (isSupplement ? "Start giving it" : "Add to daily list")
        let caption = entry.isActive
            ? "Takes it off your daily list. Its history stays."
            : "Adds it to your daily list at the times below."
        return VStack(alignment: .leading, spacing: Spacing.x2) {
            Button(title) {
                if entry.isActive { confirmingStop = true } else { Task { await start(entry) } }
            }
            .buttonStyle(.primary)
            .disabled(working || (!entry.isActive && blocks(entry).isEmpty))
            Text(caption)
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - How much and when

    private func times(_ entry: PlanEntries.Entry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("How much and when")
                .textStyle(.label)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                HStack {
                    Text("Amount").textStyle(.body).foregroundStyle(palette.ink)
                    Spacer(minLength: Spacing.x3)
                    Text(entry.amount ?? "As the plan says")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .multilineTextAlignment(.trailing)
                }
                .frame(minHeight: 56)
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                ForEach(entry.times) { time in
                    Toggle(isOn: binding(entry, time.block)) {
                        Text(time.block.title).textStyle(.body).foregroundStyle(palette.ink)
                    }
                    .tint(palette.accent)
                    .frame(minHeight: 56)
                    .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    .disabled(working)
                }
            }
            .overlay(alignment: .top) { palette.hairline.frame(height: Rule.width) }
        }
    }

    /// Before it starts, a switch only changes what Start will use; after, it saves.
    private func binding(_ entry: PlanEntries.Entry, _ block: TodoBlock) -> Binding<Bool> {
        Binding(
            get: { blocks(entry).contains(block) },
            set: { on in
                if entry.isActive {
                    Task { await change { try await $0.set(entry, block, on: on) } }
                } else {
                    var next = blocks(entry)
                    if on { next.insert(block) } else { next.remove(block) }
                    chosen = next
                }
            }
        )
    }

    private func blocks(_ entry: PlanEntries.Entry) -> Set<TodoBlock> {
        if !entry.isActive, let chosen { return chosen }
        return Set(entry.times.filter(\.isOn).map(\.block))
    }

    // MARK: - Dose steps

    /// The parent's own steps ("From Oct 12, 4 drops"). Never made up from the plan's words.
    private func doseSteps(_ entry: PlanEntries.Entry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Dose steps")
                .textStyle(.label)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            if entry.item.doseSteps.isEmpty {
                Text("If the plan says to work up slowly, add each step here. To do shows the right amount each day.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(entry.item.doseSteps, id: \.self) { step in
                    HStack {
                        Text("From \(PlanWords.day(step.startDate))").textStyle(.body).foregroundStyle(palette.ink)
                        Spacer(minLength: Spacing.x3)
                        Text(step.amount).textStyle(.body).foregroundStyle(palette.graphite)
                    }
                    .frame(minHeight: 52)
                    .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    .contextMenu {
                        Button("Remove this step", systemImage: "trash", role: .destructive) {
                            Task { await change { try await $0.removeDoseStep(entry, step) } }
                        }
                    }
                }
            }
            Button("Add a step") { addingStep = true }
                .buttonStyle(.textLink)
        }
    }

    // MARK: - What the plan says

    private func words(_ entry: PlanEntries.Entry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("What the plan says")
                .textStyle(.label)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(entry.words)
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.leading, Spacing.x4)
                .overlay(alignment: .leading) { palette.hairline.frame(width: 2) }
        }
    }

    // MARK: - Saving

    private func start(_ entry: PlanEntries.Entry) async {
        let blocks = TodoBlock.allCases.filter(blocks(entry).contains)
        await change { try await $0.start(entry, at: blocks) }
        chosen = nil
        announce(entry.kind == .supplement ? "Started. It's in your daily list." : "Added to your daily list.")
    }

    private func stop(_ entry: PlanEntries.Entry) async {
        await change { try await $0.stop(entry) }
        announce(entry.kind == .supplement ? "Stopped. Its history stays." : "Removed from your daily list. Its history stays.")
    }

    private func change(_ work: (PlanEntryActions) async throws -> Void) async {
        guard let child = model.child?.id, let container = try? CaliCareModelContainer.shared() else { return }
        working = true
        defer { working = false }
        do {
            try await work(PlanEntryActions(container: container, child: child))
            await LogChanges.didChange()
        } catch {
            model.problem = "Couldn't save that just now. Please try again."
        }
        await model.load()
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }

    private func stopTitle(_ entry: PlanEntries.Entry) -> String {
        entry.kind == .supplement ? "Stop giving \(entry.label.replacingOccurrences(of: "Give ", with: ""))?" : "Remove it from your daily list?"
    }

    private func stopButton(_ entry: PlanEntries.Entry) -> String {
        entry.kind == .supplement ? "Stop giving it" : "Remove from daily list"
    }
}

/// "Add a step": an amount, in the parent's words, and the day it starts.
private struct DoseStepSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Date) -> Void
    @State private var amount = ""
    @State private var date = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount, like 4 drops", text: $amount)
                        .textStyle(.body)
                    DatePicker("Starts", selection: $date, displayedComponents: .date)
                        .tint(palette.accent)
                } footer: {
                    Text("Use the amount your provider gave you. To do shows it from this day on.")
                        .textStyle(.meta)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .navigationTitle("Add a step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(amount.trimmingCharacters(in: .whitespacesAndNewlines), Calendar.current.startOfDay(for: date))
                        dismiss()
                    }
                    .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium])
    }
}
