import Core
import SwiftUI

/// One part of the day's steps, joined by a rail: indigo where two done steps
/// meet, hairline elsewhere. In the open part, the first step not done is
/// "Next", on an oat row with an indigo ring.
struct StepList: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let block: TodoDay.Block
    /// The part that's open now (only it gets a "Next").
    let isOpen: Bool
    let skin: TodoDay.Skin?
    let onTick: (TodoDay.Item, TodoBlock) -> Void
    let onOpen: (TodoDay.Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
                    title
                    Spacer(minLength: 0)
                    hint
                }
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    title
                    hint
                }
            }
            if block.items.isEmpty {
                Text("Nothing here yet. Tap Change the list to add steps.")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(block.items.enumerated()), id: \.element.id) { index, item in
                        StepRow(
                            item: item,
                            isNext: isOpen && item.id == block.next?.id,
                            railAbove: index == 0 ? nil : joined(block.items[index - 1], item),
                            railBelow: index == block.items.count - 1 ? nil : joined(item, block.items[index + 1]),
                            pips: isSkin(item) ? skin?.pips : nil,
                            doneAt: item.doneAt.map { model.time($0) },
                            onTick: { onTick(item, block.block) },
                            onOpen: { onOpen(item) }
                        )
                    }
                }
            }
        }
    }

    private var title: some View {
        Text(block.block.title)
            .textStyle(.title)
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var hint: some View {
        Text("Tap a step to see how").textStyle(.meta).foregroundStyle(palette.graphite)
    }

    /// The rail between two steps is indigo only when both are done.
    private func joined(_ a: TodoDay.Item, _ b: TodoDay.Item) -> Bool { a.isDone && b.isDone }

    private func isSkin(_ item: TodoDay.Item) -> Bool { if case .skin = item.kind { true } else { false } }
}

private struct StepRow: View {
    @Environment(\.palette) private var palette
    let item: TodoDay.Item
    let isNext: Bool
    /// nil: no rail on that side (first or last step). true: indigo.
    let railAbove: Bool?
    let railBelow: Bool?
    let pips: [TodoDay.Skin.Pip]?
    let doneAt: String?
    let onTick: () -> Void
    let onOpen: () -> Void

    private var isSkin: Bool { if case .skin = item.kind { true } else { false } }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x2) {
            Button(action: onTick) {
                circle
                    .frame(width: 44, height: 56, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.label)
            .accessibilityValue(item.isDone ? (item.meta ?? "Done") : (item.meta ?? "Not done"))
            .accessibilityHint(isSkin ? "Logs one round." : (item.isDone ? "Marks it not done." : "Marks it done."))

            Button(action: onOpen) {
                HStack(spacing: Spacing.x3) {
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        if isNext {
                            Text("Next").textStyle(.meta).fontWeight(.semibold).foregroundStyle(palette.indigo)
                        }
                        Text(item.label)
                            .textStyle(.body)
                            .fontWeight(isNext ? .semibold : .regular)
                            .foregroundStyle(item.isDone && !isSkin ? palette.graphite : palette.ink)
                        meta
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let doneAt, item.isDone, !isSkin {
                        Text("Done \(doneAt)").textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                    if !item.isDone {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.graphite)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, Spacing.x3)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows how, and the plan's words.")
        }
        .padding(.horizontal, Spacing.x3)
        .background(alignment: .leading) { rail.padding(.leading, Spacing.x3 + 13) }
        .background(isNext ? palette.oat : .clear, in: RoundedRectangle(cornerRadius: Corner.tight))
        .padding(.horizontal, -Spacing.x3)
    }

    @ViewBuilder private var circle: some View {
        if item.isDone {
            Circle().fill(palette.indigo)
                .overlay(Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(palette.paper))
                .frame(width: 28, height: 28)
        } else {
            Circle()
                .fill(isNext ? palette.oat : palette.paper)
                .overlay(Circle().strokeBorder(isNext ? palette.indigo : palette.ink, lineWidth: isNext ? 2 : 1.5))
                .frame(width: 28, height: 28)
        }
    }

    /// Two halves: from the step above to this one, and on to the next.
    private var rail: some View {
        VStack(spacing: 0) {
            half(railAbove)
            half(railBelow)
        }
        .frame(width: 2)
        .accessibilityHidden(true)
    }

    private func half(_ state: Bool?) -> some View {
        Rectangle().fill(state.map { $0 ? palette.indigo : palette.hairline } ?? .clear)
    }

    @ViewBuilder private var meta: some View {
        if let pips {
            HStack(spacing: Spacing.x2) {
                HStack(spacing: Spacing.x1) {
                    ForEach(Array(pips.enumerated()), id: \.offset) { _, pip in
                        Circle()
                            .fill(pip == .done ? palette.indigo : .clear)
                            .overlay(Circle().strokeBorder(palette.indigo,
                                                           style: StrokeStyle(lineWidth: 1.5, dash: pip == .optional ? [2, 2] : [])))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
                if let text = item.meta { Text(text).textStyle(.meta).foregroundStyle(palette.graphite) }
            }
        } else if let text = item.meta {
            Text(text).textStyle(.meta).foregroundStyle(palette.graphite)
        }
    }
}
