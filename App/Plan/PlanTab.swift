import Core
import PDFKit
import QuickLook
import SwiftUI

/// Plan: the care plan from the provider, read first. No plan yet: bring one
/// in. A draft: finish checking it. A running plan: "Open the full plan",
/// then the plan by section; each item opens its own page, the only place
/// anything changes. Then the rest of the plan's pages and "Add a new plan".
struct PlanTab: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var plan: CarePlanInfo?
    @State private var adding: AddPlanSheet.Source??
    @State private var reviewing: CarePlanInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Plan", caption: caption)
                    VStack(alignment: .leading, spacing: 0) {
                        switch plan?.status {
                        case .draft?:
                            PlanDraft(plan: plan!) { reviewing = plan }
                        case .active?:
                            PlanList(plan: plan!)
                        default:
                            PlanEmpty { adding = .some($0) }
                        }
                        PlanMore(onAdd: plan?.status == .active ? { adding = .some(nil) } : nil)
                            .padding(.top, Spacing.section)
                    }
                    .padding(.horizontal, Spacing.margin)
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .statusBarBackground()
            .navigationTitle("Plan")
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
        }
    }

    /// "What Dr. Rivera's plan says"
    private var caption: String? {
        guard plan?.status == .active, let plan else { return nil }
        return plan.provider.isEmpty ? "What your provider\u{2019}s plan says" : "What \(plan.provider)\u{2019}s plan says"
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

// MARK: - The rest of the plan

/// The plan's other pages, one row each, then "Add a new plan" last.
private struct PlanMore: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    /// Shown with a running plan: opens the reader for a new one.
    let onAdd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanHeading("More")
            VStack(spacing: 0) {
                PlanRow(title: "Supplements", detail: supplementsDetail) { SupplementsScreen() }
                if hasBaths {
                    PlanRow(title: "Baths", detail: nil) { BathsScreen() }
                }
                PlanRow(title: "Patch tests", detail: nil) { PatchTestsScreen() }
                PlanRow(title: "Visits and journal", detail: visitsDetail) { VisitsScreen() }
                PlanRow(title: "Food", detail: foodDetail) { FoodListView() }
                PlanRow(title: "Products", detail: productsDetail) { ProductListView() }
                if let onAdd {
                    Button(action: onAdd) {
                        PlanListRow(label: "Add a new plan", meta: "Scan it, or add the PDF")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.x2)
        }
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
