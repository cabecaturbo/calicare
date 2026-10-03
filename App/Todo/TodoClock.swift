import Foundation

/// The time To do works from. Debug builds can pin it for screenshots with
/// `-todoClock 08:05` (today at that time).
enum TodoClock {
    static func now() -> Date {
        #if DEBUG
        if let pinned = UserDefaults.standard.string(forKey: "todoClock") {
            let parts = pinned.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2,
               let date = Calendar.autoupdatingCurrent.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now) {
                return date
            }
        }
        #endif
        return .now
    }
}
