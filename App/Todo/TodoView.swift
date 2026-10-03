import Core
import SwiftUI

/// To do: "What do I do right now?" The open block's things to tick, the other
/// blocks as one row each, and Edit. Nothing else.
struct TodoView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var editing = false
    @State private var showing: TodoDay.Item?
    @State private var expanded: TodoBlock?
    @State private var asking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "To do", onEdit: { editing = true })
                    if let todo = model.todo {
                        if todo.allDone && expanded == nil {
                            AllDone(nextMorning: todo.nextMorning)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, Spacing.x5)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(todo.blocks) { block in
                                if block.block == (expanded ?? todo.open) {
                                    OpenBlock(block: block, onTick: tick, onOpen: { showing = $0 })
                                        .padding(.vertical, Spacing.x5)
                                } else {
                                    BlockRow(block: block) { withAnimation { expanded = block.block } }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $editing, onDismiss: { Task { await model.load() } }) {
                RoutineEditor().nightAwarePalette()
            }
            .sheet(item: $showing, onDismiss: { Task { await model.load() } }) { item in
                TodoItemSheet(item: item).nightAwarePalette()
            }
            .sheet(isPresented: $asking, onDismiss: { Task { await model.load() } }) {
                GivingQuestionSheet().nightAwarePalette()
            }
            .task { await model.load() }
            .task(id: needsAsking) { if needsAsking { asking = true } }
            .onChange(of: model.todo?.open) { _, _ in expanded = nil }
        }
    }

    /// The plan has supplements nobody has said yes or no to yet.
    private var needsAsking: Bool {
        GivingQuestionSheet.unanswered(Array(model.planItems.values), logs: model.supplementLogs).isEmpty == false
    }

    private func tick(_ item: TodoDay.Item, _ block: TodoBlock) {
        if item.isDone, case .skin = item.kind {
            // Skin care counts rounds: another tap is another round.
            Task { await model.todoTick(item, in: block) }
        } else if item.isDone, let log = item.lastLog {
            Task { await model.deleteWithUndo(log) }
        } else {
            Task { await model.todoTick(item, in: block) }
        }
    }
}

/// The open block: its name, "3 of 5 done", and its rows.
private struct OpenBlock: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let block: TodoDay.Block
    let onTick: (TodoDay.Item, TodoBlock) -> Void
    let onOpen: (TodoDay.Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(block.block.title)
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(block.items.isEmpty ? "Nothing here yet. Tap Edit to add steps." : block.progress)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            VStack(spacing: 0) {
                ForEach(block.items) { item in
                    TodoRow(item: item, done: item.doneAt.map { model.time($0) },
                            onTick: { onTick(item, block.block) }, onOpen: { onOpen(item) })
                }
            }
        }
    }
}

/// A block that isn't open: its name and time (or Done), one row.
private struct BlockRow: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let block: TodoDay.Block
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AdaptiveStack {
                Text(block.block.title).textStyle(.body).foregroundStyle(palette.ink)
                Spacer(minLength: 0)
                Text(block.isDone ? "Done" : model.time(block.startsAt))
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.graphite)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows this list.")
    }
}

/// "All done for tonight." and when the morning list starts.
private struct AllDone: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let nextMorning: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text("All done for tonight.")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Morning list starts at \(model.time(nextMorning)).")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
    }
}

/// A big check circle (its own target), the label, one short meta line, and
/// when it was done. Tapping the words opens the item's sheet.
private struct TodoRow: View {
    @Environment(\.palette) private var palette
    let item: TodoDay.Item
    let done: String?
    let onTick: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x2) {
            Button(action: onTick) {
                ZStack {
                    if item.isDone {
                        Circle().fill(palette.indigo)
                        Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(palette.paper)
                    } else {
                        Circle().strokeBorder(palette.ink, lineWidth: 1.5)
                    }
                }
                .frame(width: 28, height: 28)
                .frame(width: 48, height: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.label)
            .accessibilityValue(item.isDone ? (item.meta ?? "Done") : (item.meta ?? "Not done"))
            .accessibilityHint(isSkin ? "Logs one round." : (item.isDone ? "Marks it not done." : "Marks it done."))

            Button(action: onOpen) {
                AdaptiveStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .textStyle(.body)
                            .foregroundStyle(item.isDone && !isSkin ? palette.graphite : palette.ink)
                        if let meta = item.meta {
                            Text(meta).textStyle(.meta).foregroundStyle(palette.graphite)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let done, !isSkin {
                        Text("Done \(done)").textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                }
                .padding(.vertical, Spacing.x2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows what to do and the plan's words.")
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }

    private var isSkin: Bool { if case .skin = item.kind { true } else { false } }
}
