import SwiftUI

// Design tokens from CLAUDE.md. Never red for "bad"; severity uses sage lightness.

// MARK: - Colors

public struct Palette: Sendable, Equatable {
    public let background: Color
    public let card: Color
    public let ink: Color
    public let muted: Color
    public let accent: Color
    /// Text/icons placed on `accent`.
    public let onAccent: Color
    /// Text on light sage.
    public let sageDark: Color
    /// "Avoid" and "worth watching" labels.
    public let clay: Color
    /// Callout boxes.
    public let sand: Color
    public let severityLow: Color
    public let severityMedium: Color
    public let severityHigh: Color
    public let isNight: Bool

    public static let day = Palette(
        background: Color(hex: 0xF8F3EA),
        card: Color(hex: 0xFFFFFF),
        ink: Color(hex: 0x2B2622),
        muted: Color(hex: 0x6B6259),
        accent: Color(hex: 0x4F6F57),
        onAccent: Color(hex: 0xFFFFFF),
        sageDark: Color(hex: 0x3F5E47),
        clay: Color(hex: 0x8A5A3C),
        sand: Color(hex: 0xF0E6D6),
        severityLow: Color(hex: 0xC9D6C9),
        severityMedium: Color(hex: 0x8FA995),
        severityHigh: Color(hex: 0x3F5E47),
        isNight: false
    )

    /// 8 PM – 7 AM. Warm and dim: no bright whites. Only the background is
    /// specified in CLAUDE.md; the rest are proposed values (all text ≥ 4.5:1).
    public static let night = Palette(
        background: Color(hex: 0x1E1B18),
        card: Color(hex: 0x2A2521),
        ink: Color(hex: 0xE8DFD2),
        muted: Color(hex: 0xA89E92),
        accent: Color(hex: 0x8FA995),
        onAccent: Color(hex: 0x1E1B18),
        sageDark: Color(hex: 0xA9BDAE),
        clay: Color(hex: 0xC4A58E),
        sand: Color(hex: 0x332D28),
        severityLow: Color(hex: 0x3A443C),
        severityMedium: Color(hex: 0x4F6655),
        severityHigh: Color(hex: 0x8FA995),
        isNight: true
    )

    public static func current(at date: Date = .now, calendar: Calendar = .current) -> Palette {
        NightMode.isActive(at: date, calendar: calendar) ? .night : .day
    }
}

public enum NightMode {
    public static let startHour = 20
    public static let endHour = 7

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

extension EnvironmentValues {
    public var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Fonts

/// Fraunces for headings, DM Sans for body. All scale with Dynamic Type.
/// Call `FontRegistry.registerAll()` once per process before use.
public enum Typography {
    public static let largeTitle = Font.custom("Fraunces-SemiBold", size: 34, relativeTo: .largeTitle)
    public static let title = Font.custom("Fraunces-SemiBold", size: 28, relativeTo: .title)
    public static let title2 = Font.custom("Fraunces-Medium", size: 22, relativeTo: .title2)
    public static let title3 = Font.custom("Fraunces-Medium", size: 20, relativeTo: .title3)
    public static let headline = Font.custom("DMSans-SemiBold", size: 17, relativeTo: .headline)
    public static let body = Font.custom("DMSans-Regular", size: 17, relativeTo: .body)
    public static let bodyMedium = Font.custom("DMSans-Medium", size: 17, relativeTo: .body)
    public static let callout = Font.custom("DMSans-Regular", size: 16, relativeTo: .callout)
    public static let caption = Font.custom("DMSans-Medium", size: 13, relativeTo: .caption)
    public static let button = Font.custom("DMSans-SemiBold", size: 17, relativeTo: .body)
}

// MARK: - Spacing, radii, sizes

public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let s: CGFloat = 12
    public static let m: CGFloat = 16
    /// Card padding.
    public static let l: CGFloat = 20
    public static let xl: CGFloat = 28
    public static let xxl: CGFloat = 40
}

public enum Radius {
    public static let card: CGFloat = 18
    public static let small: CGFloat = 10
    // Pills use Capsule() (fully rounded).
}

public enum TouchTarget {
    public static let minimum: CGFloat = 44
    /// Bigger one-hand buttons at night.
    public static let night: CGFloat = 60
}
