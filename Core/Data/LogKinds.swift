import Foundation

public enum LogType: String, Codable, Sendable, CaseIterable {
    case nightRating
    case itchEpisode
    case flare
    case bowelMovement
    case mood
    case routineDone
    case note
    /// The parent's one daily answer: how was the skin today? The only source of "skin by day".
    case skinToday
    /// One of the care plan's baths. Which bath: the plan item's id, in `routineStepID`.
    case bath
    /// A patch test: what and where in `note`; the result, once checked, in `value`.
    case patchTest
    /// A care plan supplement started, taken, or stopped. Which one: the plan item's id, in `routineStepID`.
    case supplement

    /// Whether a log of this type must carry a value.
    public var requiresValue: Bool {
        switch self {
        case .nightRating, .mood, .skinToday, .supplement: true
        // A one-tap widget log records that it happened; the kind is optional.
        case .bowelMovement, .itchEpisode, .flare, .routineDone, .note, .bath, .patchTest: false
        }
    }

    /// True when `value` is the right kind for this type (or absent when none is expected).
    public func accepts(_ value: LogValue?) -> Bool {
        switch (self, value) {
        case (.nightRating, .night?), (.bowelMovement, .bowel?), (.mood, .mood?), (.routineDone, .routine?),
             (.skinToday, .skin?), (.patchTest, .patch?), (.supplement, .supplement?): true
        case (_, nil): !requiresValue
        default: false
        }
    }
}

public enum NightRating: String, Codable, Sendable, CaseIterable {
    case good, okay, rough
}

public enum BowelMovement: String, Codable, Sendable, CaseIterable {
    case good, hard, loose, none
}

public enum Mood: String, Codable, Sendable, CaseIterable {
    case great, okay, cranky
}

/// Which routine a `routineDone` log was for.
public enum RoutineTime: String, Codable, Sendable, CaseIterable {
    case morning, evening

    /// The routine a one-tap "Routine done" most likely means: morning before 2 PM, evening after.
    public static func likely(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> RoutineTime {
        calendar.component(.hour, from: date) < 14 ? .morning : .evening
    }
}

/// The daily skin answer, drawn on indigo steps 1, 2, 4, and 5 (light is calm).
public enum SkinToday: String, Codable, Sendable, CaseIterable {
    case calm, littleItchy, flaring, veryRough

    /// Step on the five-step indigo scale.
    public var step: Int {
        switch self {
        case .calm: 1
        case .littleItchy: 2
        case .flaring: 4
        case .veryRough: 5
        }
    }

    /// "a little itchy", for sentences.
    public var words: String {
        switch self {
        case .calm: "calm"
        case .littleItchy: "a little itchy"
        case .flaring: "flaring"
        case .veryRough: "very rough"
        }
    }

    /// "A little itchy", for buttons.
    public var title: String {
        words.prefix(1).uppercased() + words.dropFirst()
    }
}

/// How a patch test looked when checked. Only what the parent saw.
public enum PatchResult: String, Codable, Sendable, CaseIterable {
    case noReaction, someRedness, reaction

    public var title: String {
        switch self {
        case .noReaction: "No reaction"
        case .someRedness: "Some redness"
        case .reaction: "A reaction"
        }
    }
}

/// What happened with a plan supplement.
public enum SupplementEvent: String, Codable, Sendable, CaseIterable {
    case started, taken, stopped
}

/// Where a flare was. Optional, and never required to log one.
public enum BodyArea: String, Codable, Sendable, CaseIterable {
    case face, neck, hands, arms, elbowCreases, torso, back, diaperArea, legs, kneeCreases, feet

    public var words: String {
        switch self {
        case .elbowCreases: "elbow creases"
        case .diaperArea: "diaper area"
        case .kneeCreases: "knee creases"
        default: rawValue
        }
    }
}

/// Where a log came from.
public enum EntrySource: String, Codable, Sendable, CaseIterable {
    case widget, intent, notification, app, watch
}

/// The optional value attached to a log.
public enum LogValue: Hashable, Sendable {
    case night(NightRating)
    case bowel(BowelMovement)
    case mood(Mood)
    case routine(RoutineTime)
    case skin(SkinToday)
    case patch(PatchResult)
    case supplement(SupplementEvent)

    public var rawValue: String {
        switch self {
        case .night(let rating): rating.rawValue
        case .bowel(let movement): movement.rawValue
        case .mood(let mood): mood.rawValue
        case .routine(let time): time.rawValue
        case .skin(let answer): answer.rawValue
        case .patch(let result): result.rawValue
        case .supplement(let event): event.rawValue
        }
    }

    /// Rebuilds a stored value. Returns nil if `raw` doesn't fit `type`.
    public init?(type: LogType, raw: String) {
        switch type {
        case .nightRating:
            guard let rating = NightRating(rawValue: raw) else { return nil }
            self = .night(rating)
        case .bowelMovement:
            guard let movement = BowelMovement(rawValue: raw) else { return nil }
            self = .bowel(movement)
        case .mood:
            guard let mood = Mood(rawValue: raw) else { return nil }
            self = .mood(mood)
        case .routineDone:
            guard let time = RoutineTime(rawValue: raw) else { return nil }
            self = .routine(time)
        case .skinToday:
            guard let answer = SkinToday(rawValue: raw) else { return nil }
            self = .skin(answer)
        case .patchTest:
            guard let result = PatchResult(rawValue: raw) else { return nil }
            self = .patch(result)
        case .supplement:
            guard let event = SupplementEvent(rawValue: raw) else { return nil }
            self = .supplement(event)
        case .itchEpisode, .flare, .note, .bath:
            return nil
        }
    }
}
