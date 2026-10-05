import Core
import SwiftUI

/// To do (canvas "To do v2"): the header and why-line, one big statement
/// ("3 things left for bedtime."), the parts of the day as cards, then the
/// shown part's steps on a rail, and "Change the list". All done shows the
/// moon instead of the list.
struct TodoView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var editing = false
    @State private var showing: TodoDay.Item?
    @State private var picked: TodoBlock?
    @State private var asking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TodoHeader(why: why)
                    if let todo = model.todo {
                        let summary = todo.summary(time: model.time)
                        VStack(alignment: .leading, spacing: Spacing.x1) {
                            Text(summary.statement)
                                .textStyle(.statement)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            if let line = summary.line {
                                Text(line).textStyle(.body).foregroundStyle(palette.graphite)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, Spacing.x6)

                        DayParts(blocks: todo.blocks, shown: shown(in: todo)) { block in
                            withAnimation { picked = block }
                        }
                        .padding(.top, Spacing.x5)

                        if let block = todo.blocks.first(where: { $0.block == shown(in: todo) }) {
                            StepList(block: block, isOpen: block.block == todo.open, skin: todo.skin,
                                     onTick: tick, onOpen: { showing = $0 })
                                .padding(.top, Spacing.x6)
                        } else if todo.allDone {
                            AllDoneRest(name: model.child?.name)
                                .padding(.top, Spacing.x6)
                        }
                    }
                    Button("Change the list") { editing = true }
                        .buttonStyle(.textLink)
                        .padding(.top, Spacing.x5)
                }
                .padding(.horizontal, Spacing.margin)
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
            .onChange(of: model.todo?.open) { _, _ in picked = nil }
        }
    }

    /// The part whose list shows: the one tapped, else the open one (none when all done).
    private func shown(in todo: TodoDay) -> TodoBlock? { picked ?? todo.open }

    /// "What to do today, from Cal's care plan."
    private var why: String {
        let name = model.child?.name ?? "your child"
        return model.activePlan == nil ? "What to do today for \(name)." : "What to do today, from \(name)'s care plan."
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

/// "Rest up. Cal's list is clear." under the moon.
private struct AllDoneRest: View {
    @Environment(\.palette) private var palette
    let name: String?

    var body: some View {
        VStack(spacing: Spacing.x3) {
            Illustration(kind: .moon, size: CGSize(width: 140, height: 120))
            Text(name.map { "Rest up. \($0)'s list is clear." } ?? "Rest up. The list is clear.")
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
