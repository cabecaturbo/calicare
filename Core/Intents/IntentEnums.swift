import AppIntents

/// The log types offered in Siri and Shortcuts. Notes are left out: they need text.
public enum LogEventKind: String, CaseIterable, AppEnum {
    case nightRating, itchEpisode, flare, bowelMovement, mood, routineDone, skinToday

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
    public static let caseDisplayRepresentations: [LogEventKind: DisplayRepresentation] = [
        .nightRating: "Night",
        .itchEpisode: "Itching",
        .flare: "Flare",
        .bowelMovement: "Bowel movement",
        .mood: "Mood",
        .routineDone: "Routine done",
        .skinToday: "Skin today",
    ]

    public var logType: LogType {
        switch self {
        case .nightRating: .nightRating
        case .itchEpisode: .itchEpisode
        case .flare: .flare
        case .bowelMovement: .bowelMovement
        case .mood: .mood
        case .routineDone: .routineDone
        case .skinToday: .skinToday
        }
    }
}

extension NightRating: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Night"
    public static let caseDisplayRepresentations: [NightRating: DisplayRepresentation] = [
        .good: "Good",
        .okay: "Okay",
        .rough: "Rough",
    ]
}

extension BowelMovement: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bowel movement"
    public static let caseDisplayRepresentations: [BowelMovement: DisplayRepresentation] = [
        .good: "Good",
        .hard: "Hard",
        .loose: "Loose",
        BowelMovement.none: "None",
    ]
}

extension SkinToday: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Skin today"
    public static let caseDisplayRepresentations: [SkinToday: DisplayRepresentation] = [
        .calm: "Calm",
        .littleItchy: "A little itchy",
        .flaring: "Flaring",
        .veryRough: "Very rough",
    ]
}

extension Mood: AppEnum {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Mood"
    public static let caseDisplayRepresentations: [Mood: DisplayRepresentation] = [
        .great: "Great",
        .okay: "Okay",
        .cranky: "Cranky",
    ]
}
