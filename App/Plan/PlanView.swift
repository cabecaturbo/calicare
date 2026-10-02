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
                            .padding(.top, Spacing.x3)

                        let other = model.progress(next == .morning ? .evening : .morning)
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            Text(other.time == .morning ? "Morning" : "Evening")
                                .textStyle(.section)
                                .foregroundStyle(palette.ink)
                                .accessibilityAddTraits(.isHeader)
                            RoutineRows(progress: other)
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)

                        let baths = model.bathWeek
                        if !baths.rows.isEmpty {
                            BathsSection(week: baths)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x6)
                        }

                        editButton
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x5)

                        CarePlanSection()
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.section)
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
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

/// One routine's rows: a check row per step, or one row for the whole routine.
private struct RoutineRows: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let progress: RoutineProgress

    var body: some View {
        VStack(spacing: 0) {
            if progress.steps.isEmpty {
                let done = progress.wholeRoutineLog
                CheckRow(
                    title: progress.time == .morning ? "Morning routine" : "Evening routine",
                    done: done.map { model.time($0.timestamp) },
                    label: progress.time == .morning ? "Log morning routine done" : "Log evening routine done"
                ) {
                    Task { await model.log(.routineDone, value: .routine(progress.time)) }
                }
            } else {
                ForEach(progress.steps) { step in
                    let done = progress.doneLogs[step.id]
                    // A plan step shows how often the plan says, e.g. "3–4x/day".
                    let often = step.planItemID.flatMap { model.planItems[$0]?.frequency }
                    CheckRow(title: step.name, detail: often, done: done.map { model.time($0.timestamp) }, label: step.name) {
                        if let done {
                            Task { await model.deleteWithUndo(done) }
                        } else {
                            Task { await model.tick(step) }
                        }
                    }
                }
            }
        }
    }
}

/// A circle that fills with a check, the name, and the time it was done.
private struct CheckRow: View {
    @Environment(\.palette) private var palette
    let title: String
    var detail: String?
    let done: String?
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x3) {
                ZStack {
                    if done != nil {
                        Circle().fill(palette.indigo)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.paper)
                    } else {
                        Circle().strokeBorder(palette.ink, lineWidth: 1)
                    }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.body)
                        .foregroundStyle(done == nil ? palette.ink : palette.graphite)
                    if let detail {
                        Text(detail)
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                }
                Spacer()
                if let done {
                    Text("Done \(done)")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(done.map { "Done \($0)" } ?? "Not done")
        .accessibilityHint(done == nil ? "Marks it done." : "Marks it not done.")
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
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.text).textStyle(.body).foregroundStyle(palette.ink)
                                let details = [row.item.frequency, row.item.duration].compactMap { $0 }
                                    .filter { !row.item.text.localizedCaseInsensitiveContains($0) }
                                if !details.isEmpty {
                                    Text(details.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                                }
                            }
                            Spacer()
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
