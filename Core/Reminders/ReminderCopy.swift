import Foundation

/// Reminder wording: warm, short, never "you missed."
public enum ReminderCopy {
    /// `things` is how many things are in that To do block ("Bedtime: 5 things").
    public static func title(_ kind: ReminderKind, childName: String, things: Int? = nil) -> String {
        switch kind {
        case .checkIn: return "How was last night for \(childName)?"
        case .skinCheckIn: return "How was \(childName)'s skin today?"
        case .morningRoutine, .afternoonRoutine, .eveningRoutine:
            let block = kind.todoBlock?.title ?? ""
            guard let things, things > 0 else { return "\(block) list for \(childName)" }
            return "\(block): \(things) thing\(things == 1 ? "" : "s")"
        case .tonight: return "Put Quick Log on your Lock Screen?"
        }
    }

    public static func body(_ kind: ReminderKind, childName: String = "") -> String {
        switch kind {
        case .checkIn, .skinCheckIn: "One tap is enough."
        case .morningRoutine, .afternoonRoutine, .eveningRoutine:
            childName.isEmpty ? "Tap All done when it's all done." : "For \(childName). Tap All done when it's all done."
        case .tonight: "Tap to add the Log button to your Lock Screen."
        }
    }

    /// The name in Settings.
    public static func settingsTitle(_ kind: ReminderKind) -> String {
        switch kind {
        case .checkIn: "Morning check-in"
        case .skinCheckIn: "Evening skin check-in"
        case .morningRoutine: "Morning list"
        case .afternoonRoutine: "Afternoon list"
        case .eveningRoutine: "Bedtime list"
        case .tonight: "Quick Log reminder"
        }
    }
}
