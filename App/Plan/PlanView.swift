import Core
import SwiftUI

/// Plan (UX.md §5): the routine you set, what's up next first. With steps,
/// each is a check row; without, the routine is one row that logs it done.
/// The provider's plan arrives with import (Phase 4); until then it's absent.
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
                            art: next == .morning ? .sun : .moon
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

                        editButton
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x5)
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
                    CheckRow(title: step.name, done: done.map { model.time($0.timestamp) }, label: step.name) {
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
                Text(title)
                    .textStyle(.body)
                    .foregroundStyle(done == nil ? palette.ink : palette.graphite)
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
