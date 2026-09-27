import Core
import SwiftUI

/// Plan (UX.md §5): the routine you set, what's up next first. Until routine
/// steps can be edited, each routine is one row that logs it done.
/// The provider's plan arrives with import (Phase 4); until then it's absent.
struct PlanView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Plan", caption: "The routine you set, morning and evening")
                    if model.child != nil {
                        SummaryCard(
                            eyebrow: "Up next",
                            title: nextTitle,
                            caption: lastDone(next).map { "Done \(model.time($0.timestamp))" },
                            art: next == .morning ? .sun : .moon
                        )
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)

                        VStack(spacing: 0) {
                            row(for: next)
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x3)

                        let other: RoutineTime = next == .morning ? .evening : .morning
                        VStack(alignment: .leading, spacing: Spacing.x2) {
                            Text(other == .morning ? "Morning" : "Evening")
                                .textStyle(.section)
                                .foregroundStyle(palette.ink)
                                .accessibilityAddTraits(.isHeader)
                            row(for: other)
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Morning until 2 PM, evening after.
    private var next: RoutineTime { RoutineTime.likely(at: .now) }

    private var nextTitle: String {
        let name = next == .morning ? "Morning" : "Evening"
        return lastDone(next) == nil ? "\(name) · not done yet" : "\(name) · done"
    }

    private func row(for time: RoutineTime) -> some View {
        let done = lastDone(time)
        return Button {
            Task { await model.log(.routineDone, value: .routine(time)) }
        } label: {
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
                Text(time == .morning ? "Morning routine" : "Evening routine")
                    .textStyle(.body)
                    .foregroundStyle(done == nil ? palette.ink : palette.graphite)
                Spacer()
                if let done {
                    Text("Done \(model.time(done.timestamp))")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(time == .morning ? "Log morning routine done" : "Log evening routine done")
        .accessibilityValue(done.map { "Done \(model.time($0.timestamp))" } ?? "")
    }

    /// Today's most recent log for this routine.
    private func lastDone(_ time: RoutineTime) -> LogEntry? {
        model.entries.first { $0.type == .routineDone && $0.value == .routine(time) }
    }
}
