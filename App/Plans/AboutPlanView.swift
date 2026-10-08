import Core
import QuickLook
import SwiftUI

/// "About this plan": who it's from, when it started, every item as written,
/// the original file (on this phone), and ending the plan.
struct AboutPlanView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let plan: CarePlanInfo
    @State private var items: [PlanItemInfo] = []
    @State private var preview: URL?
    @State private var confirmingEnd = false
    @State private var length: Int?

    /// "Length": how long the plan runs. Saved only when the parent picks one;
    /// the plan's own longest duration is offered, never set for them.
    private var lengthRow: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            HStack {
                Text("Length").textStyle(.body).foregroundStyle(palette.ink)
                Spacer(minLength: Spacing.x3)
                Picker("Length", selection: Binding(get: { length ?? 0 }, set: { save($0 == 0 ? nil : $0) })) {
                    Text("Not set").tag(0)
                    ForEach(1...52, id: \.self) { weeks in
                        Text(weeks == 1 ? "1 week" : "\(weeks) weeks").tag(weeks)
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.accent)
            }
            .frame(minHeight: Size.touchTarget)
            if length == nil, let suggested = PlanStar.suggestedWeeks(items) {
                Button("The plan says about \(suggested) weeks. Use that") { save(suggested) }
                    .buttonStyle(.textLink)
            }
        }
    }

    private func save(_ weeks: Int?) {
        length = weeks
        Task {
            try? await CarePlanStore(modelContainer: CaliCareModelContainer.shared()).setLength(plan.id, weeks: weeks)
            await LogChanges.didChange()
        }
    }

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
                    lengthRow
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
        .onAppear { length = plan.lengthWeeks }
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
