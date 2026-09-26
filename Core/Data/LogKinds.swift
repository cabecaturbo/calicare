import Foundation

public enum LogType: String, Codable, Sendable, CaseIterable {
    case nightRating
    case itchEpisode
    case flare
    case bowelMovement
    case mood
    case routineDone
    case note

    /// Whether a log of this type must carry a value.
    public var requiresValue: Bool {
        switch self {
        case .nightRating, .mood: true
        // A one-tap widget log records that it happened; the kind is optional.
        case .bowelMovement, .itchEpisode, .flare, .routineDone, .note: false
        }
    }

    /// True when `value` is the right kind for this type (or absent when none is expected).
    public func accepts(_ value: LogValue?) -> Bool {
        switch (self, value) {
        case (.nightRating, .night?), (.bowelMovement, .bowel?), (.mood, .mood?), (.routineDone, .routine?): true
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

    public var rawValue: String {
        switch self {
        case .night(let rating): rating.rawValue
        case .bowel(let movement): movement.rawValue
        case .mood(let mood): mood.rawValue
        case .routine(let time): time.rawValue
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
        case .itchEpisode, .flare, .note:
            return nil
        }
    }
}
