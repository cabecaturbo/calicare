import Core
import SwiftUI

/// Plan (UX.md §5): the routine you set, what's up next first. With steps,
/// each is a check row; without, the routine is one row that logs it done.
/// Then the care plan section: add the provider's plan, review it, or open it.
struct PlanView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Plan", caption: "The routine you set, morning and evening")
                    if model.child != nil {
                        let up = model.progress(next)
                        SummaryCard(
                            eyebrow: "Up next",
                            title: up.title,
                            caption: up.finishedAt.map { "Done \(model.time($0))" },
                            art: next == .morning ? .sprout : .lamp
                        )
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)

                        RoutineRows(progress: up)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x4)

                        let other = model.progress(next == .morning ? .evening : .morning)
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            Text(other.time == .morning ? "Morning" : "Evening")
                                .textStyle(.section)
                                .foregroundStyle(palette.ink)
                                .accessibilityAddTraits(.isHeader)
                            RoutineRows(progress: other)
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x7)

                        editButton
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x2)

                        let baths = model.bathWeek
                        if !baths.rows.isEmpty {
                            BathsSection(week: baths)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x7)
                        }

                        let supplements = model.supplementPlan
                        if !supplements.rows.isEmpty || !supplements.mentioned.isEmpty {
                            SupplementsSection(plan: supplements)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x7)
                        }

                        let patches = model.patchTests
                        if !patches.isEmpty {
                            PatchTestsSection(tests: patches)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x7)
                        }

                        CarePlanSection()
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.section)

                        if model.activePlan != nil || !model.visits.isEmpty {
                            ProviderSection(tracker: model.providerTracker)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x7)
                        }

                        FoodSection()
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x7)

                        ProductsSection()
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x7)
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $editing, onDismiss: { Task { await model.load() } }) {
                RoutineEditor()
                    .nightAwarePalette()
            }
        }
    }

    /// Morning until 2 PM, evening after.
    private var next: RoutineTime { RoutineTime.likely(at: .now) }

    private var editButton: some View {
        let hasSteps = !model.routineSteps.isEmpty
        return VStack(alignment: .leading, spacing: Spacing.x1) {
            if !hasSteps {
                Text("Add the steps from your plan, in your own words, to tick them off one by one.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(hasSteps ? "Edit routine" : "Add steps") { editing = true }
                .buttonStyle(.textLink)
        }
    }
}

/// The plan's baths: one tap logs one, with this week's count. Never picks a
/// bath; the plan's own rules ("rotate, don't combine") sit underneath.
private struct BathsSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let week: BathWeek

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Baths")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(week.rows) { row in
                    Button { Task { await model.logBath(row.item) } } label: {
                        AdaptiveStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.text).textStyle(.body).foregroundStyle(palette.ink)
                                let details = [row.item.frequency, row.item.duration].compactMap { $0 }
                                    .filter { !row.item.text.localizedCaseInsensitiveContains($0) }
                                if !details.isEmpty {
                                    Text(details.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(count(row))
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(row.item.text)")
                    .accessibilityValue(count(row))
                }
            }
            ForEach(week.notes, id: \.self) { note in
                Text(note).textStyle(.meta).foregroundStyle(palette.graphite)
            }
        }
    }

    /// "1 of 3 this week", or "1 this week" when the plan doesn't say how many.
    private func count(_ row: BathWeek.Row) -> String {
        row.perWeek.map { "\(row.doneThisWeek) of \($0) this week" } ?? "\(row.doneThisWeek) this week"
    }
}

/// Plan's Food: a count by status and the way into the food list.
private struct FoodSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Food")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            NavigationLink {
                FoodListView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Food list").textStyle(.body).foregroundStyle(palette.ink)
                        Text(summary).textStyle(.meta).foregroundStyle(palette.graphite)
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
    }

    /// "12 safe · 1 testing · 3 paused", or a line saying what it's for.
    private var summary: String {
        guard !model.foods.isEmpty else { return "Safe, testing, and paused foods" }
        return FoodStatus.allCases.compactMap { status in
            let count = model.foods.filter { $0.status == status }.count
            return count > 0 ? "\(count) \(status.title.lowercased())" : nil
        }.joined(separator: " · ")
    }
}
