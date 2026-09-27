import Foundation

/// Reminder wording: warm, short, never "you missed."
public enum ReminderCopy {
    public static func title(_ kind: ReminderKind, childName: String) -> String {
        switch kind {
        case .checkIn: "How was last night for \(childName)?"
        case .skinCheckIn: "How was \(childName)'s skin today?"
        case .morningRoutine: "Time for \(childName)'s morning routine"
        case .eveningRoutine: "Time for \(childName)'s evening routine"
        }
    }

    public static func body(_ kind: ReminderKind) -> String {
        switch kind {
        case .checkIn, .skinCheckIn: "One tap is enough."
        case .morningRoutine, .eveningRoutine: "Tap Done whenever you're ready."
        }
    }

    /// The name in Settings.
    public static func settingsTitle(_ kind: ReminderKind) -> String {
        switch kind {
        case .checkIn: "Morning check-in"
        case .skinCheckIn: "Evening skin check-in"
        case .morningRoutine: "Morning routine"
        case .eveningRoutine: "Evening routine"
        }
    }
}
