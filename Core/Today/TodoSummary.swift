import Foundation

/// To do v2's words and marks: the big statement, each part of the day's
/// status, the next thing, and the skin-care dots. Pure, so it's tested.
extension TodoDay {
    /// "3 things left for bedtime." and "Next: Do skin care."
    public struct Summary: Equatable, Sendable {
        public let statement: String
        public let line: String?

        public init(statement: String, line: String?) {
            self.statement = statement
            self.line = line
        }
    }

    /// The statement for now: what's left in the open block, or all done.
    public func summary(time: (Date) -> String) -> Summary {
        guard let open, let block = blocks.first(where: { $0.block == open }) else {
            return Summary(statement: "All done for today.", line: "Morning list starts at \(time(nextMorning)).")
        }
        guard let next = block.next else {
            return Summary(statement: "Nothing on the list for \(open.phrase).", line: "Tap Change the list to add steps.")
        }
        let left = block.items.count - block.doneCount
        return Summary(statement: "\(left == 1 ? "1 thing" : "\(left) things") left for \(open.phrase).",
                       line: "Next: \(next.label).")
    }
}

extension TodoDay.Block {
    /// The first thing not done yet.
    public var next: TodoDay.Item? { items.first { !$0.isDone } }

    /// "Done", "2 of 5", or "Nothing yet".
    public var status: String {
        if items.isEmpty { return "Nothing yet" }
        return isDone ? "Done" : "\(doneCount) of \(items.count)"
    }

    /// How full the card's bar is, 0 to 1.
    public var fraction: Double {
        items.isEmpty ? 0 : Double(doneCount) / Double(items.count)
    }
}

extension TodoDay.Skin {
    /// One dot per round: done, still due (up to the plan's low count), or
    /// optional (up to its high count). Extra rounds add done dots.
    public enum Pip: Equatable, Sendable { case done, due, optional }

    public var pips: [Pip] {
        let low = target?.lowerBound ?? 1
        let high = max(target?.upperBound ?? 1, low)
        return (0..<max(high, rounds)).map { index in
            index < rounds ? .done : (index < low ? .due : .optional)
        }
    }
}

extension TodoBlock {
    /// "the morning", "the afternoon", "bedtime": for "3 things left for bedtime."
    public var phrase: String {
        switch self {
        case .morning: "the morning"
        case .afternoon: "the afternoon"
        case .bedtime: "bedtime"
        }
    }
}
