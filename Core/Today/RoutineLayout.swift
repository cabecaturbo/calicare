import Foundation

/// How one routine reads on Plan: tasks in order, consecutive Apply steps
/// grouped under "Skin" and numbered, and notes ("3-4x per day") shown as
/// a badge instead of as steps to tick.
public struct RoutineLayout: Equatable, Sendable {
    public enum Entry: Equatable, Sendable, Identifiable {
        case step(RoutineStepInfo)
        /// Two or more Apply steps in a row, in order.
        case skin([RoutineStepInfo])

        public var id: String {
            switch self {
            case .step(let step): step.id.uuidString
            case .skin(let steps): "skin-" + (steps.first?.id.uuidString ?? "")
            }
        }
    }

    public let entries: [Entry]
    /// "3-4x per day", from a note in this routine, shown on the Apply steps.
    public let applyBadge: String?
    /// Notes in this routine, in their own words.
    public let notes: [RoutineStepInfo]

    public init(steps: [RoutineStepInfo]) {
        let ordered = steps.sorted { $0.order < $1.order }
        notes = ordered.filter { $0.kind == .note }
        applyBadge = notes.lazy.compactMap { StepLabeler.frequencyPhrase(in: $0.original) }.first
        var entries: [Entry] = []
        var run: [RoutineStepInfo] = []
        func flush() {
            if run.count > 1 { entries.append(.skin(run)) } else { entries += run.map(Entry.step) }
            run = []
        }
        for step in ordered where step.kind == .task {
            if step.category == .apply {
                run.append(step)
            } else {
                flush()
                entries.append(.step(step))
            }
        }
        flush()
        self.entries = entries
    }

    /// Task steps only, in display order: what "Up next" counts.
    public var tasks: [RoutineStepInfo] {
        entries.flatMap { entry -> [RoutineStepInfo] in
            switch entry {
            case .step(let step): [step]
            case .skin(let steps): steps
            }
        }
    }
}
