import SwiftUI

// Tokens from DESIGN.md: paper, ink, rose, and sage. Only this file should change
// if the palette or the serif is ever swapped.

// MARK: - Color

public struct Palette: Sendable, Equatable {
    public enum Token: String, CaseIterable, Sendable {
        /// Main background everywhere.
        case paper
        /// Secondary surface: sheets, selected rows, the log confirmation.
        case oat
        /// Text, primary buttons, full-strength rules.
        case ink
        /// Secondary text, captions, timestamps.
        case graphite
        /// 0.5pt rules between rows and sections.
        case hairline
        /// The one accent: selected states, links, charts.
        case accent
        /// "Worth watching" text only, used rarely. Paper only: it fails on oat.
        case ochre
    }

    /// A text color on a background color that screens are allowed to use.
    public struct TextPair: Sendable, Equatable {
        public let text: Token
        public let background: Token
    }

    public let isNight: Bool
    private let tokens: [Token: UInt32]
    /// Sage density, calm first. Day: light is calm. Night: brighter is harder.
    /// Never red: rose is the accent, never a severity.
    public let severityScale: [UInt32]

    /// Blush and rose (owner, October 5, 2026): blush paper, a dusty rose
    /// accent for buttons and links only, and a warm sage skin scale.
    public static let day = Palette(
        isNight: false,
        tokens: [
            .paper: 0xF9F0EC, .oat: 0xF2E2DC, .ink: 0x2B1D1F, .graphite: 0x6E5A5C,
            .hairline: 0xE6D0CA, .accent: 0x9E4357, .ochre: 0x8A6320,
        ],
        severityScale: [0xEAEDE1, 0xCCD6BF, 0xADBDA0, 0x8FA382, 0x56704C]
    )

    /// 8 PM – 7 AM keeps the night layout (bigger Log button and rows) but,
    /// since October 5, 2026, the same colors as the day: no dark mode.
    public static let night = Palette(
        isNight: true,
        tokens: Palette.day.tokens,
        severityScale: Palette.day.severityScale
    )

    /// Every text-on-background combination the UI may use. The contrast test
    /// holds each one to 4.5:1 in both palettes. Paper on ink is the primary button.
    public static let textPairs: [TextPair] = [
        TextPair(text: .ink, background: .paper),
        TextPair(text: .ink, background: .oat),
        TextPair(text: .graphite, background: .paper),
        TextPair(text: .graphite, background: .oat),
        TextPair(text: .accent, background: .paper),
        TextPair(text: .accent, background: .oat),
        TextPair(text: .ochre, background: .paper),
        TextPair(text: .paper, background: .ink),
    ]

    public static func current(at date: Date = .now, calendar: Calendar = .current) -> Palette {
        #if DEBUG
        if let forced = DesignReview.forcedNight { return forced ? .night : .day }
        #endif
        return NightMode.isActive(at: date, calendar: calendar) ? .night : .day
    }

    public func hex(_ token: Token) -> UInt32 {
        tokens[token] ?? 0
    }

    public func color(_ token: Token) -> Color {
        Color(hex: hex(token))
    }

    public var paper: Color { color(.paper) }
    public var oat: Color { color(.oat) }
    public var ink: Color { color(.ink) }
    public var graphite: Color { color(.graphite) }
    public var hairline: Color { color(.hairline) }
    public var accent: Color { color(.accent) }
    public var ochre: Color { color(.ochre) }

    /// A step on the severity scale, 1 (calm) to 5 (hard).
    public func severity(step: Int) -> Color {
        Color(hex: severityScale[min(max(step, 1), severityScale.count) - 1])
    }

    /// Nights on the same four marks as skin: good = calm, okay = a little itchy,
    /// rough = very rough (DESIGN.md §3). Step 3 is no longer used.
    public func color(for level: CareLevel) -> Color {
        switch level {
        case .low: severity(step: 1)
        case .medium: severity(step: 2)
        case .high: severity(step: 5)
        }
    }

    /// A skin answer at its own step: 1, 2, 4, or 5.
    public func color(for skin: SkinToday) -> Color {
        severity(step: skin.step)
    }
}

extension ChildColor {
    /// Tags keep their stored names; they now draw from the notebook palette.
    public func color(in palette: Palette) -> Color {
        switch self {
        case .sage: palette.accent
        case .clay: palette.ochre
        case .moss: palette.graphite
        case .sand: palette.oat
        }
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

// MARK: - Type

/// The type scale from DESIGN.md §4: five sizes. Newsreader (bundled, OFL) only
/// for headlines and hero words; SF Pro for everything else, body included.
/// `lede`, `section`, `control`, and `meta` are the older names, kept so every
/// screen moved to the new scale at once: lede = title, section = label,
/// control = body, meta = caption.
/// Call `FontRegistry.registerAll()` once per process before use.
public enum TypeStyle: CaseIterable, Sendable {
    /// Newsreader 500, 34/40: the screen title ("Today"), the Welcome headline.
    case display
    /// Newsreader 500, 24/30: summary card titles, the skin question, hero words.
    case title
    /// Same as title (the old summary-sentence style).
    case lede
    /// Newsreader 500, 20/26: section headers ("Evening", "Supplements").
    case section
    /// SF Pro 600, 15/20: the child switcher, step numbers, outlined button labels.
    case label
    /// SF Pro 400, 17/24: all body copy and row labels.
    case body
    /// Same as body (the old control style).
    case control
    /// SF Pro 400, 13/18: times, eyebrows, footnotes.
    case meta
    /// Newsreader 400, 40/46: the one big statement at the top of To do
    /// ("3 things left for bedtime.") and its step sheet.
    case statement

    public var font: Font {
        switch self {
        case .display: .custom(Self.displayCut, size: 34, relativeTo: .largeTitle)
        case .title, .lede: .custom(Self.displayCut, size: 24, relativeTo: .title2)
        case .section: .custom(Self.displayCut, size: 20, relativeTo: .title3)
        case .label: .system(.subheadline, weight: .semibold)
        case .body, .control: .system(.body)
        case .meta: .system(.footnote)
        case .statement: .custom(Self.statementCut, size: 40, relativeTo: .largeTitle)
        }
    }

    /// Point size and line height from DESIGN.md, before Dynamic Type scaling.
    public var size: CGFloat {
        switch self {
        case .display: 34
        case .title, .lede: 24
        case .section: 20
        case .label: 15
        case .body, .control: 17
        case .meta: 13
        case .statement: 40
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .display: 40
        case .title, .lede: 30
        case .section: 26
        case .label: 20
        case .body, .control: 24
        case .meta: 18
        case .statement: 46
        }
    }

    public var dynamicTypeBase: Font.TextStyle {
        switch self {
        case .display: .largeTitle
        case .title, .lede: .title2
        case .section: .title3
        case .label: .subheadline
        case .body, .control: .body
        case .meta: .footnote
        case .statement: .largeTitle
        }
    }

    /// Newsreader at optical size 36, weight 500 (cut from the variable font).
    static let displayCut = "NewsreaderDisplay-Medium"
    /// Newsreader at optical size 36, weight 400: the statement.
    static let statementCut = "NewsreaderDisplay-Regular"
    /// Newsreader at optical size 16, weight 400: widgets' small serif only.
    static let textCut = "NewsreaderText-Regular"
}

// MARK: - Space, corners, sizes

/// One scale: 4 / 8 / 16 / 24 / 40 (DESIGN.md §5). Space inside a group is
/// always smaller than space between groups: headers sit 8 above their rows
/// and 40 below the section before.
public enum Spacing {
    public static let x1: CGFloat = 4
    public static let x2: CGFloat = 8
    /// 12 and 32: To do v2 only (tokens.css --s3 and --s6).
    public static let x3: CGFloat = 12
    public static let x4: CGFloat = 16
    public static let x5: CGFloat = 24
    public static let x6: CGFloat = 32
    /// Between sections.
    public static let x7: CGFloat = 40
    /// Screen margins.
    public static let margin: CGFloat = 24
    public static let titleToLede: CGFloat = 8
    public static let ledeToSection: CGFloat = 40
    /// Between sections (DESIGN.md §5).
    public static let section: CGFloat = 40
}

/// Shared cards and PDFs (weekly card, caregiver card) are fixed-size
/// pictures and pages; they keep their own spacing so nothing reflows.
public enum CardSpacing {
    public static let row: CGFloat = 12
    public static let block: CGFloat = 32
}

public enum Corner {
    /// Buttons, cards, inputs (DESIGN.md §5).
    public static let control: CGFloat = 12
    /// Images and screenshots.
    public static let image: CGFloat = 2
    /// To do v2's day cards, next row, and buttons (tokens.css --r-btn).
    public static let tight: CGFloat = 4
    /// DESIGN.md §5: buttons, cards, inputs, and widget tiles (the new rule; screens move to it in U3–U5).
    public static let card: CGFloat = 12
}

public enum Rule {
    /// Hairlines between rows and sections, and the secondary button outline.
    public static let width: CGFloat = 0.5
}

public enum Size {
    public static let touchTarget: CGFloat = 44

    /// Ledger rows: roomier at night for one-handed, half-asleep taps.
    public static func row(isNight: Bool) -> CGFloat { isNight ? 72 : 56 }

    /// Primary and secondary buttons.
    public static func button(isNight: Bool) -> CGFloat { isNight ? 64 : 56 }
}
