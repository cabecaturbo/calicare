import Core
import SwiftUI

/// Plan: the care plan from the provider, and which of its steps the family
/// uses. No plan yet: bring one in. A draft: finish checking it. A running
/// plan: one big line ("Using 12 of 15 steps."), the steps to check on or
/// off, what's in the plan for reading, then the rest of the plan's pages.
struct PlanTab: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var plan: CarePlanInfo?
    @State private var adding: AddPlanSheet.Source??
    @State private var reviewing: CarePlanInfo?
    @State private var showingAbout = false
    @State private var reading: PlanItemInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Plan")
                    switch plan?.status {
                    case .draft?:
                        PlanDraft(plan: plan!) { reviewing = plan }
                    case .active?:
                        PlanChecklist(plan: plan!, onRead: { reading = $0 })
                    default:
                        PlanEmpty { adding = .some($0) }
                    }
                    PlanMore()
                        .padding(.top, Spacing.section)
                    if plan?.status == .active {
                        footer.padding(.top, Spacing.x6)
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
            .task(id: loadKey) { await load() }
            .sheet(isPresented: addingBinding, onDismiss: { Task { await load() } }) {
                if let child = model.child {
                    AddPlanSheet(child: child, source: adding ?? nil) { draft in reviewing = draft }
                        .nightAwarePalette()
                }
            }
            .sheet(item: $reviewing, onDismiss: { Task { await refresh() } }) { draft in
                PlanReviewView(plan: draft).nightAwarePalette()
            }
            .sheet(isPresented: $showingAbout, onDismiss: { Task { await refresh() } }) {
                if let plan { AboutPlanView(plan: plan).nightAwarePalette() }
            }
            .sheet(item: $reading) { item in
                PlanWordsSheet(item: item).nightAwarePalette()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.x5) {
            Button("About this plan") { showingAbout = true }
                .buttonStyle(.textLink)
            Button("Add a new plan") { adding = .some(nil) }
                .buttonStyle(.textLink)
        }
    }

    /// Looks again when the child, the running plan, or the day's load changes.
    private var loadKey: String {
        [model.child?.id.uuidString, model.activePlan?.id.uuidString, String(model.hasLoaded)]
            .map { $0 ?? "-" }.joined(separator: "|")
    }

    private var addingBinding: Binding<Bool> {
        Binding(get: { adding != nil }, set: { if !$0 { adding = nil } })
    }

    private func refresh() async {
        await load()
        await model.load()
    }

    /// The draft being checked if there is one, otherwise the running plan.
    private func load() async {
        guard let child = model.child,
              let plans = try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).plans(child: child.id)
        else { return plan = nil }
        plan = plans.first { $0.status == .draft } ?? plans.first { $0.status == .active }
    }
}

// MARK: - No plan yet

/// "Bring in your care plan." with the three ways in.
private struct PlanEmpty: View {
    @Environment(\.palette) private var palette
    let onAdd: (AddPlanSheet.Source) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanStatement("Bring in your care plan.",
                          line: "Take a photo of the plan from your provider, or add the PDF. Cali Care turns it into your daily list, in their words.")
            VStack(spacing: Spacing.x3) {
                PlanSourceCard(title: "Scan the paper", detail: "A page or a few", symbol: "camera.viewfinder") { onAdd(.scan) }
                PlanSourceCard(title: "Add a PDF", detail: "From Mail or Files", symbol: "doc") { onAdd(.file) }
                PlanSourceCard(title: "Choose a photo", detail: "One you've already taken", symbol: "photo.on.rectangle") { onAdd(.photos) }
            }
            .padding(.top, Spacing.x6)
            Text("Reading a plan needs you to sign in. The file stays on your phone.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.x4)
        }
    }
}

/// One way to bring the plan in: an icon in a circle, a name, a short line.
private struct PlanSourceCard: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x4) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(palette.accent)
                    .frame(width: 48, height: 48)
                    .background(palette.paper, in: Circle())
                    .overlay(Circle().strokeBorder(palette.hairline, lineWidth: Rule.width))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.label).foregroundStyle(palette.ink)
                    Text(detail).textStyle(.meta).foregroundStyle(palette.graphite)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.graphite)
            }
            .padding(.horizontal, Spacing.x4)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.tight))
            .overlay(RoundedRectangle(cornerRadius: Corner.tight).strokeBorder(palette.hairline, lineWidth: Rule.width))
            .contentShape(RoundedRectangle(cornerRadius: Corner.tight))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Draft

/// "Check your plan." while a read plan waits to start.
private struct PlanDraft: View {
    let plan: CarePlanInfo
    let onCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanStatement("Check your plan.",
                          line: "Keep the steps you'll use. Nothing shows in To do until you start it.")
            Button("Finish checking", action: onCheck)
                .buttonStyle(.primary)
                .padding(.top, Spacing.x6)
        }
    }
}

// MARK: - Running plan

/// The plan's steps with a check for each one the family uses.
private struct PlanChecklist: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo
    let onRead: (PlanItemInfo) -> Void

    private var use: PlanUse {
        PlanUse(items: model.planItems.values.filter { $0.planID == plan.id }, steps: model.routineSteps)
    }

    var body: some View {
        let use = use
        VStack(alignment: .leading, spacing: 0) {
            PlanStatement(use.total == 0 ? "Your plan is running." : use.statement, line: from)
            if use.total > 0 {
                HStack {
                    Text("Checked steps show in To do.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                    Spacer(minLength: Spacing.x3)
                    let allOn = use.inUse == use.total
                    Button(allOn ? "Use none" : "Use all") { save(use.changeAll(to: !allOn)) }
                        .buttonStyle(.textLink)
                }
                .padding(.top, Spacing.x5)
            }
            ForEach(PlanUse.Group.allCases, id: \.self) { group in
                let rows = use.rows(in: group)
                if !rows.isEmpty {
                    PlanHeading(group.title).padding(.top, Spacing.x6)
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            PlanUseRow(row: row, onToggle: { save([PlanUse.change(row, to: !row.isInUse)]) },
                                       onRead: { onRead(row.item) })
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: use.inUse)
    }

    /// "From Dr. Lee · started Oct 3"
    private var from: String {
        let who = plan.provider.isEmpty ? "From your provider" : "From \(plan.provider)"
        guard let started = plan.startedAt else { return who }
        return "\(who) · started \(started.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func save(_ changes: [PlanUse.Change]) {
        Task {
            do {
                let container = try CaliCareModelContainer.shared()
                try await PlanUseActions(routine: RoutineStore(modelContainer: container),
                                         plans: CarePlanStore(modelContainer: container)).apply(changes)
            } catch {
                model.problem = "Couldn't save that just now. Please try again."
            }
            await model.load()
        }
    }
}

/// A plan step: the check (in To do or not) and its name, which opens the provider's words.
private struct PlanUseRow: View {
    @Environment(\.palette) private var palette
    let row: PlanUse.Row
    let onToggle: () -> Void
    let onRead: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: onToggle) {
                circle
                    .frame(width: 44, height: 44, alignment: .leading)
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.name)
            .accessibilityValue(row.isInUse ? "In To do" : "Not in To do")
            .accessibilityHint(row.isInUse ? "Takes it out of To do." : "Adds it to To do.")

            Button(action: onRead) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
                    if let category = row.category {
                        Image(systemName: category.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(palette.accent)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        Text(row.name)
                            .textStyle(.body)
                            .foregroundStyle(row.isInUse ? palette.ink : palette.graphite)
                        if let detail = row.detail {
                            Text(detail)
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                                .lineLimit(3)
                        }
                        if let meta = row.meta {
                            Text(meta).textStyle(.meta).fontWeight(.medium).foregroundStyle(palette.graphite)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.graphite)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Spacing.x3)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows your provider's words.")
        }
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }

    @ViewBuilder private var circle: some View {
        if row.isInUse {
            Circle().fill(palette.accent)
                .overlay(Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(palette.paper))
                .frame(width: 28, height: 28)
        } else {
            Circle()
                .fill(palette.paper)
                .overlay(Circle().strokeBorder(palette.ink, lineWidth: 1.5))
                .frame(width: 28, height: 28)
        }
    }
}

/// Plan › The rest of the plan: items that never go in To do, for reading.
struct PlanReferenceScreen: View {
    @Environment(\.palette) private var palette
    let items: [PlanItemInfo]
    @State private var reading: PlanItemInfo?

    var body: some View {
        PlanPage(title: "The rest of the plan") {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Baths, food, everyday basics, and follow-ups. These don't go in To do.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        PlanReferenceRow(item: item) { reading = item }
                    }
                }
            }
        }
        .sheet(item: $reading) { item in
            PlanWordsSheet(item: item).nightAwarePalette()
        }
    }
}

/// Something in the plan for reading: its kind and its words.
private struct PlanReferenceRow: View {
    @Environment(\.palette) private var palette
    let item: PlanItemInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(item.kind.title).textStyle(.meta).foregroundStyle(palette.graphite)
                    Text(item.plainText ?? item.text)
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.graphite)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.x3)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your provider's words.")
    }
}

/// One plan item in full: the provider's words, as written.
struct PlanWordsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let item: PlanItemInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("Your provider's words")
                        .textStyle(.label)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    ProviderWords(item.providerWords)
                    let details = [item.dose, item.frequency, item.timing, item.duration].compactMap { $0 }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                            .padding(.top, Spacing.x2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.margin)
            }
            .paperBackground(.oat)
            .navigationTitle(item.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - The rest of the plan

/// The plan's other pages: one row each.
private struct PlanMore: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanHeading("More from the plan")
            VStack(spacing: 0) {
                if !reference.isEmpty {
                    PlanRow(title: "The rest of the plan", detail: "\(reference.count) more") {
                        PlanReferenceScreen(items: reference)
                    }
                }
                PlanRow(title: "Supplements", detail: supplementsDetail) { SupplementsScreen() }
                if hasBaths {
                    PlanRow(title: "Baths", detail: nil) { BathsScreen() }
                }
                PlanRow(title: "Patch tests", detail: nil) { PatchTestsScreen() }
                PlanRow(title: "Visits and journal", detail: visitsDetail) { VisitsScreen() }
                PlanRow(title: "Food", detail: foodDetail) { FoodListView() }
                PlanRow(title: "Products", detail: productsDetail) { ProductListView() }
            }
            .padding(.top, Spacing.x2)
        }
    }

    /// The running plan's items that never go in To do.
    private var reference: [PlanItemInfo] {
        guard let plan = model.activePlan else { return [] }
        return PlanUse(items: model.planItems.values.filter { $0.planID == plan.id }, steps: model.routineSteps).reference
    }

    private var hasBaths: Bool {
        let baths = model.bathWeek
        return !baths.rows.isEmpty || !baths.notes.isEmpty
    }

    private var supplementsDetail: String? {
        let rows = model.supplementPlan.rows
        guard !rows.isEmpty else { return nil }
        let giving = rows.filter { $0.item.isGiving == true }.count
        let notYet = rows.count - giving
        return notYet > 0 ? "\(giving) giving · \(notYet) not yet" : "\(giving) giving"
    }

    private var visitsDetail: String? {
        model.providerTracker.lastVisit.map { "Last visit \($0.date.formatted(.dateTime.month(.abbreviated).day()))" }
    }

    private var foodDetail: String? {
        guard !model.foods.isEmpty else { return nil }
        let safe = model.foods.filter { $0.status == .safe }.count
        let paused = model.foods.filter { $0.status == .paused }.count
        return paused > 0 ? "\(safe) safe · \(paused) paused" : "\(safe) safe"
    }

    private var productsDetail: String? {
        let inUse = model.products.filter(\.inUse).count
        return inUse > 0 ? "\(inUse) in use" : nil
    }
}

// MARK: - Shared

/// The tab's one big line and the line under it, like To do's.
private struct PlanStatement: View {
    @Environment(\.palette) private var palette
    let text: String
    let line: String?

    init(_ text: String, line: String?) {
        self.text = text
        self.line = line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(text)
                .textStyle(.statement)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let line {
                Text(line)
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Spacing.x6)
    }
}

private struct PlanHeading: View {
    @Environment(\.palette) private var palette
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .textStyle(.section)
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}
