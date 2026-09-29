import Core
import SwiftUI

/// Review a draft plan: every item with the line it came from and any blanks.
/// Check, edit, or remove each; nothing starts until "Start this plan", and
/// only checked items are kept.
struct PlanReviewView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo
    @State private var items: [PlanItemInfo] = []
    @State private var editing: PlanItemInfo?
    @State private var confirmingDiscard = false
    @State private var problem: String?

    private var confirmed: Int { items.filter(\.isConfirmed).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text("Check each item against the plan. Tap to change the wording. Nothing starts until you tap Start this plan, and only checked items are kept.")
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(confirmed == items.count ? "Uncheck all" : "Check all") { Task { await setAll(confirmed != items.count) } }
                            .buttonStyle(.textLink)
                    }
                    ForEach(PlanItemKind.allCases, id: \.self) { kind in
                        let group = items.filter { $0.kind == kind }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(kind.title)
                                    .textStyle(.section)
                                    .foregroundStyle(palette.ink)
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.bottom, Spacing.x2)
                                ForEach(group) { item in
                                    ItemRow(item: item) { Task { await toggle(item) } } onEdit: { editing = item }
                                        .contextMenu {
                                            Button("Edit") { editing = item }
                                            Button("Remove") { Task { await remove(item) } }
                                        }
                                }
                            }
                        }
                    }
                    if let problem {
                        Text(problem).textStyle(.body).foregroundStyle(palette.ink)
                    }
                    Button("Discard this draft") { confirmingDiscard = true }
                        .buttonStyle(.textLink)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x5)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .safeAreaInset(edge: .bottom) {
                Button(confirmed == 0 ? "Check items to start" : "Start this plan (\(confirmed))") { Task { await start() } }
                    .buttonStyle(.primary)
                    .disabled(confirmed == 0)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.vertical, Spacing.x3)
                    .background(palette.paper)
            }
            .navigationTitle("Review \(model.child?.name ?? "the")’s plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
            .sheet(item: $editing, onDismiss: { Task { await reload() } }) { item in
                PlanItemEditor(item: item)
                    .nightAwarePalette()
            }
            .confirmationDialog("Discard this draft?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard") { Task { await discard() } }
            } message: {
                Text("The items and the saved file are removed from this phone.")
            }
        }
        .tint(palette.indigo)
        .task { await reload() }
    }

    private var store: CarePlanStore? {
        (try? CaliCareModelContainer.shared()).map { CarePlanStore(modelContainer: $0) }
    }

    private func reload() async {
        items = (try? await store?.items(plan: plan.id)) ?? []
    }

    private func toggle(_ item: PlanItemInfo) async {
        try? await store?.setConfirmed(item.id, !item.isConfirmed)
        await reload()
    }

    private func setAll(_ on: Bool) async {
        for item in items where item.isConfirmed != on { try? await store?.setConfirmed(item.id, on) }
        await reload()
    }

    private func remove(_ item: PlanItemInfo) async {
        try? await store?.remove(item.id)
        await reload()
    }

    private func start() async {
        do {
            try await store?.start(plan.id)
            await LogChanges.didChange()
            await model.load()
            dismiss()
        } catch {
            problem = "Couldn’t start the plan just now. Please try again."
        }
    }

    private func discard() async {
        try? await store?.delete(plan.id)
        PlanFiles.delete(plan.sourceFileName)
        await model.load()
        dismiss()
    }
}

/// One item: a check, the plan's words, its details, any blanks, and its source.
private struct ItemRow: View {
    @Environment(\.palette) private var palette
    let item: PlanItemInfo
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.x1) {
            Button(action: onToggle) {
                ZStack {
                    if item.isConfirmed {
                        Circle().fill(palette.indigo)
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(palette.paper)
                    } else {
                        Circle().strokeBorder(palette.ink, lineWidth: 1)
                    }
                }
                .frame(width: 24, height: 24)
                .frame(width: 36, height: Size.touchTarget, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isConfirmed ? "Checked" : "Not checked")
            .accessibilityHint("Checks this item against the plan.")

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(item.text)
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                    let details = PlanDetail.allCases.compactMap { detail in item.value(detail).map { "\(detail.title): \($0)" } }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .textStyle(.meta)
                            .foregroundStyle(palette.ink)
                    }
                    ForEach(item.blanks, id: \.self) { blank in
                        Text("\(blank.title): your provider left this blank. Worth asking at your next visit.")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                    if let line = item.sourceLine {
                        Text("\(item.sourcePage.map { "Page \($0) · " } ?? "")“\(line)”")
                            .textStyle(.meta)
                            .italic()
                            .foregroundStyle(palette.graphite)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit the wording.")
        }
        .padding(.vertical, Spacing.x3)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

/// Change an item's wording or details. The source line never changes.
private struct PlanItemEditor: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let item: PlanItemInfo
    @State private var draft: PlanItemDraft
    @State private var problem: String?

    init(item: PlanItemInfo) {
        self.item = item
        _draft = State(initialValue: PlanItemDraft(
            kind: item.kind, text: item.text, dose: item.dose, frequency: item.frequency, timing: item.timing,
            duration: item.duration, sourcePage: item.sourcePage, sourceLine: item.sourceLine
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("In the plan’s words") {
                    TextField("Item", text: $draft.text, axis: .vertical)
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(PlanItemKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    field(.dose, $draft.dose)
                    field(.frequency, $draft.frequency)
                    field(.timing, $draft.timing)
                    field(.duration, $draft.duration)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Fill these only with what the plan says. Leave a detail empty if the plan does.")
                }
                if let line = item.sourceLine {
                    Section("From the plan") {
                        Text("\(item.sourcePage.map { "Page \($0) · " } ?? "")“\(line)”").italic()
                    }
                }
                if let problem { Text(problem) }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
        }
        .tint(palette.indigo)
    }

    private func field(_ detail: PlanDetail, _ value: Binding<String?>) -> some View {
        TextField(detail.title, text: Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 }))
    }

    private func save() async {
        do {
            try await CarePlanStore(modelContainer: try CaliCareModelContainer.shared()).update(item.id, with: draft)
            dismiss()
        } catch CarePlanStoreError.emptyText {
            problem = "An item needs its words."
        } catch {
            problem = "Couldn’t save that change. Please try again."
        }
    }
}
