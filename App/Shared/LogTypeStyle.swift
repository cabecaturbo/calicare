import Core

extension LogType {
    /// SF Symbol for buttons and timeline rows.
    var symbol: String {
        switch self {
        case .nightRating: "moon.zzz"
        case .itchEpisode: "hand.raised"
        case .flare: "sparkles"
        case .bowelMovement: "toilet"
        case .mood: "face.smiling"
        case .routineDone: "checkmark.circle"
        case .note: "note.text"
        }
    }
}

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
