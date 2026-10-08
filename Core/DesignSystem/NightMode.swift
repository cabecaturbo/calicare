import SwiftUI

public enum NightMode {
    public static let startHour = 20
    public static let endHour = 7

    /// The night layout (bigger Log button, "Tonight so far") follows the
    /// clock, whatever colors the parent picked with the day/night toggle.
    public static func isLayoutActive(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        #if DEBUG
        if let forced = DesignReview.forcedNight { return forced }
        #endif
        return isActive(at: date, calendar: calendar)
    }

    public static func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= startHour || hour < endHour
    }

    /// The next moment night mode switches on or off.
    public static func nextChange(after date: Date, calendar: Calendar = .current) -> Date {
        let hour = isActive(at: date, calendar: calendar) ? endHour : startHour
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(3600)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .day
}

private struct NightLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    public var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }

    /// The night layout (bigger Log button, "So far tonight"), from the clock.
    /// Set with the palette and refreshed every minute, so it switches on time.
    public var nightLayout: Bool {
        get { self[NightLayoutKey.self] }
        set { self[NightLayoutKey.self] = newValue }
    }
}

#if DEBUG
/// Debug builds only: pins day or night so design-review screenshots don't
/// depend on the clock. Shared through the App Group so widgets follow too.
public enum DesignReview {
    static let key = "designReview.forcedNight"

    /// nil means follow the clock.
    public static var forcedNight: Bool? {
        get { AppGroup.defaults.object(forKey: key) as? Bool }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    /// Reads `-designReviewNight YES|NO` from the app's launch arguments. With no
    /// argument the override is cleared. Returns true if anything changed.
    @discardableResult
    public static func applyLaunchArgument(_ defaults: UserDefaults = .standard) -> Bool {
        let requested: Bool? = switch defaults.string(forKey: "designReviewNight") {
        case "YES": true
        case "NO": false
        default: nil
        }
        guard requested != forcedNight else { return false }
        forcedNight = requested
        return true
    }
}
#endif

/// The day/night toggle: automatic (night colors 8 PM – 7 AM), or pinned to
/// day or night colors. Shared through the App Group so widgets follow.
public enum AppearanceMode: String, CaseIterable, Sendable {
    case automatic, day, night

    public static let key = "appearance.mode"

    public static var current: AppearanceMode {
        get { AppGroup.defaults.string(forKey: key).flatMap(AppearanceMode.init(rawValue:)) ?? .automatic }
        set { AppGroup.defaults.set(newValue.rawValue, forKey: key) }
    }

    static let movedToSettingsKey = "appearance.movedToSettings"

    /// The old floating sun/moon button saved day or night for good, often by
    /// accident. It's gone (Settings › Appearance now), so once, go back to
    /// following the clock. A choice made in Settings after this is kept.
    public static func resetOldButtonChoice(_ defaults: UserDefaults = AppGroup.defaults) {
        guard !defaults.bool(forKey: movedToSettingsKey) else { return }
        defaults.set(AppearanceMode.automatic.rawValue, forKey: key)
        defaults.set(true, forKey: movedToSettingsKey)
    }
}
