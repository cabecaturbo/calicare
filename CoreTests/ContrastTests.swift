import Core
import Foundation
import Testing

/// WCAG 2.x contrast for every text/background pair the UI may use.
struct ContrastTests {
    @Test(arguments: [Palette.day, Palette.night])
    func everyTextPairIsAtLeastAA(palette: Palette) {
        for pair in Palette.textPairs {
            let ratio = Self.contrast(palette.hex(pair.text), palette.hex(pair.background))
            #expect(
                ratio >= 4.5,
                "\(pair.text) on \(pair.background) is \(ratio) in \(palette.isNight ? "night" : "day")"
            )
        }
    }

    /// Every color used for text has at least one approved background.
    @Test func everyTextTokenHasAPair() {
        let textTokens: Set<Palette.Token> = [.ink, .graphite, .accent, .ochre, .paper]
        let covered = Set(Palette.textPairs.map(\.text))
        #expect(textTokens.isSubset(of: covered))
    }

    /// Ochre fails on oat (4.3:1), so it must never be listed there.
    @Test func ochreStaysOnPaper() {
        #expect(!Palette.textPairs.contains { $0.text == .ochre && $0.background == .oat })
        #expect(Self.contrast(Palette.day.hex(.ochre), Palette.day.hex(.oat)) < 4.5)
    }

    /// Spot-checks against the ratios written in DESIGN.md.
    @Test func matchesTheDesignDoc() {
        let day = Palette.day, night = Palette.night
        #expect(abs(Self.contrast(day.hex(.ink), day.hex(.paper)) - 14.5) < 0.1)
        #expect(abs(Self.contrast(day.hex(.graphite), day.hex(.oat)) - 5.2) < 0.1)
        #expect(abs(Self.contrast(day.hex(.ochre), day.hex(.paper)) - 4.7) < 0.1)
        #expect(abs(Self.contrast(night.hex(.ink), night.hex(.paper)) - 14.2) < 0.1)
        #expect(abs(Self.contrast(night.hex(.accent), night.hex(.paper)) - 10.6) < 0.1)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
