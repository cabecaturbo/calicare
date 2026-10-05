import Core
import QuickLook
import SwiftUI

/// Plan's care plan section: add a plan, finish reviewing a draft, or open
/// the plan that's running ("About this plan").
struct CarePlanSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var plan: CarePlanInfo?
    @State private var adding = false
    @State private var reviewing: CarePlanInfo?
    @State private var showingAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Care plan")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            switch plan?.status {
            case .draft?:
                row("Finish checking your plan", detail: plan.map(providerLine)) { reviewing = plan }
            case .active?:
                row("About this plan", detail: plan.map(providerLine)) { showingAbout = true }
            default:
                Text("Scan or pick the plan from \(model.child?.name ?? "your child")’s provider.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Add your care plan") { adding = true }
                    .buttonStyle(.textLink)
            }
        }
        .task(id: model.child?.id) { await load() }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) {
            if let child = model.child {
                AddPlanSheet(child: child) { draft in reviewing = draft }
                    .nightAwarePalette()
            }
        }
        .sheet(item: $reviewing, onDismiss: { Task { await load() } }) { draft in
            PlanReviewView(plan: draft)
                .nightAwarePalette()
        }
        .sheet(isPresented: $showingAbout, onDismiss: { Task { await load() } }) {
            if let plan {
                AboutPlanView(plan: plan)
                    .nightAwarePalette()
            }
        }
    }

    private func providerLine(_ plan: CarePlanInfo) -> String {
        let from = plan.provider.isEmpty ? "From your provider" : "From \(plan.provider)"
        guard let started = plan.startedAt else { return from }
        return "\(from) · started \(started.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func row(_ title: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.body).foregroundStyle(palette.ink)
                    if let detail { Text(detail).textStyle(.meta).foregroundStyle(palette.graphite) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.graphite)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
    }

    /// The draft being reviewed if there is one, otherwise the running plan.
    private func load() async {
        guard let child = model.child,
              let plans = try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).plans(child: child.id)
        else { return plan = nil }
        plan = plans.first { $0.status == .draft } ?? plans.first { $0.status == .active }
    }
}

/// "About this plan": who it's from, when it started, every item as written,
/// the original file (on this phone), and ending the plan.
struct AboutPlanView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let plan: CarePlanInfo
    @State private var items: [PlanItemInfo] = []
    @State private var preview: URL?
    @State private var confirmingEnd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        Text(plan.provider.isEmpty ? "Your provider’s plan" : "From \(plan.provider)")
                            .textStyle(.title)
                            .foregroundStyle(palette.ink)
                        if let started = plan.startedAt {
                            Text("Started \(started.formatted(date: .abbreviated, time: .omitted))")
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                    }
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            Text("How often and how long").textStyle(.section).foregroundStyle(palette.ink)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(notes) { item in
                                Text(item.text).textStyle(.body).foregroundStyle(palette.ink)
                            }
                        }
                    }
                    ForEach(PlanItemKind.allCases, id: \.self) { kind in
                        let parents = Set(items.compactMap(\.parentItemID))
                        let group = items.filter { $0.kind == kind && !parents.contains($0.id) }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.x2) {
                                Text(kind.title).textStyle(.section).foregroundStyle(palette.ink)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(group) { item in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.text).textStyle(.body).foregroundStyle(palette.ink)
                                        let details = PlanDetail.allCases.compactMap { d in item.value(d).map { "\(d.title): \($0)" } }
                                        if !details.isEmpty {
                                            Text(details.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let name = plan.sourceFileName, FileManager.default.fileExists(atPath: PlanFiles.url(for: name).path) {
                        Button("Open the file") { preview = PlanFiles.url(for: name) }
                            .buttonStyle(.textLink)
                    }
                    Button("End this plan") { confirmingEnd = true }
                        .buttonStyle(.textLink)
                    Text("Cali Care keeps the plan your provider gave you. Not medical advice.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
            .paperBackground()
            .solidNavigationBar(.paper)
            .navigationTitle("About this plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .quickLookPreview($preview)
            .confirmationDialog("End this plan?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End this plan") {
                    Task {
                        try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).end(plan.id)
                        await LogChanges.didChange()
                        dismiss()
                    }
                }
            } message: {
                Text("It stops showing in Plan. Its items stay in your history.")
            }
        }
        .tint(palette.accent)
        .task {
            items = (try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).items(plan: plan.id)) ?? []
        }
    }

    /// Routine lines that say how often or how long ("Continue … for 60-90
    /// days past when the skin is clear"): notes, not steps to tick.
    private var notes: [PlanItemInfo] {
        items.filter { item in
            (item.kind == .routineStep || item.kind == .topicalStep)
                && StepLabeler.wording(for: item.text, planKind: item.kind, frequency: item.frequency, duration: item.duration).kind == .note
        }
    }
}
