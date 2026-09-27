import Core

extension NightRating {
    var title: String { rawValue.capitalized }
}

extension BowelMovement {
    var title: String { self == .none ? "None" : rawValue.capitalized }
}

extension Mood {
    var title: String { rawValue.capitalized }
}

extension RoutineTime {
    var title: String { rawValue.capitalized }
}
