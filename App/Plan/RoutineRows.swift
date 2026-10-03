import Core
import SwiftUI

/// One routine's rows (UX.md §5): a row per step in order, consecutive Apply
/// steps grouped under "Skin" and numbered, notes shown as a badge rather
/// than as steps. With no steps, one row logs the whole routine.
struct RoutineRows: View {
    @Environment(TodayModel.self) private var model
    let progress: RoutineProgress
    @State private var showing: RoutineStepInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if progress.steps.isEmpty {
                let done = progress.wholeRoutineLog
                StepRow(
                    title: progress.time == .morning ? "Morning routine" : "Evening routine",
                    done: done.map { model.time($0.timestamp) },
                    onTick: { Task { await model.log(.routineDone, value: .routine(progress.time)) } }
                )
            } else {
                let layout = RoutineLayout(steps: progress.steps + progress.notes)
                ForEach(layout.entries) { entry in
                    switch entry {
                    case .step(let step):
                        row(step, number: nil, meta: step.category == .apply ? (meta(step) ?? layout.applyBadge) : meta(step))
                    case .skin(let steps):
                        SkinHeader(badge: layout.applyBadge)
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            row(step, number: index + 1, meta: meta(step))
                        }
                    }
                }
            }
        }
        .sheet(item: $showing, onDismiss: { Task { await model.load() } }) { step in
            StepSourceSheet(step: step)
                .nightAwarePalette()
        }
    }

    private func row(_ step: RoutineStepInfo, number: Int?, meta: String?) -> some View {
        let done = progress.doneLogs[step.id]
        return StepRow(
            title: step.displayName,
            number: number,
            detail: meta,
            done: done.map { model.time($0.timestamp) },
            onTick: {
                if let done { Task { await model.deleteWithUndo(done) } } else { Task { await model.tick(step) } }
            },
            onOpen: { showing = step }
        )
    }

    /// One line under the label: the plan's detail, first letter capitalised.
    private func meta(_ step: RoutineStepInfo) -> String? {
        guard let detail = step.detail, !detail.isEmpty else { return nil }
        return detail.prefix(1).uppercased() + detail.dropFirst()
    }
}

/// "Skin", with its symbol and how often the plan says ("3-4x per day").
private struct SkinHeader: View {
    @Environment(\.palette) private var palette
    let badge: String?

    var body: some View {
        // Side by side when it fits; the badge drops under "Skin" at large text sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.x2) { title; badgeView }
            VStack(alignment: .leading, spacing: Spacing.x1) { title; badgeView }
        }
        .padding(.top, Spacing.x4)
        .padding(.bottom, Spacing.x1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var title: some View {
        HStack(spacing: Spacing.x2) {
            Image(systemName: StepCategory.apply.symbol)
                .font(.body)
                .foregroundStyle(palette.graphite)
                .accessibilityHidden(true)
            Text("Skin")
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
        }
        .fixedSize()
    }

    @ViewBuilder private var badgeView: some View {
        if let badge {
            Text(badge)
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.x2)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: Corner.control).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }
}

/// A check circle (its own 44pt target), the label, one meta line, and the
/// time it was done. Tapping the words shows the plan's original line.
private struct StepRow: View {
    @Environment(\.palette) private var palette
    let title: String
    var number: Int?
    var detail: String?
    let done: String?
    let onTick: () -> Void
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x2) {
            Button(action: onTick) {
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
                .frame(width: Size.touchTarget, height: Size.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(done.map { "Done \($0)" } ?? "Not done")
            .accessibilityHint(done == nil ? "Marks it done." : "Marks it not done.")

            Button { onOpen?() } label: {
                HStack(alignment: .center, spacing: Spacing.x2) {
                    VStack(alignment: .leading, spacing: 2) {
                        (number.map { Text("\($0)  ").foregroundStyle(palette.graphite) } ?? Text(""))
                            + Text(title).foregroundStyle(done == nil ? palette.ink : palette.graphite)
                        if let detail {
                            Text(detail)
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                    }
                    .textStyle(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let done {
                        Text("Done \(done)")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                }
                .padding(.vertical, Spacing.x2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onOpen == nil)
            .accessibilityHint(onOpen == nil ? "" : "Shows the plan's words and lets you rename it.")
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}
