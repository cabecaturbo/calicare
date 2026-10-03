import SwiftUI

extension View {
    /// Switches between the day and night palettes automatically (8 PM – 7 AM).
    public func nightAwarePalette() -> some View {
        modifier(NightAwarePaletteModifier())
    }

    /// One of the seven type styles, with its line height. Scales with Dynamic Type.
    public func textStyle(_ style: TypeStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }

    /// Paper (or oat) with the faint grain, edge to edge.
    public func paperBackground(_ surface: Surface = .paper) -> some View {
        modifier(PaperBackgroundModifier(surface: surface))
    }
}

/// The two backgrounds content can sit on.
public enum Surface: Sendable {
    case paper
    /// For things above the page: sheets and the log confirmation.
    case oat
}

private struct NightAwarePaletteModifier: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.everyMinute) { context in
            let palette = Palette.current(at: context.date)
            content
                .environment(\.palette, palette)
                .preferredColorScheme(palette.isNight ? .dark : .light)
        }
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: TypeStyle
    /// Leading beyond the font's natural ~1.2× line height, scaled with the text.
    @ScaledMetric private var extraLeading: CGFloat

    init(style: TypeStyle) {
        self.style = style
        _extraLeading = ScaledMetric(
            wrappedValue: max(0, style.lineHeight - style.size * 1.2),
            relativeTo: style.dynamicTypeBase
        )
    }

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(extraLeading)
    }
}

extension View {
    /// Paper behind the status bar, so a screen with a hidden navigation bar
    /// doesn't scroll its content under the clock.
    public func statusBarBackground() -> some View {
        modifier(StatusBarBackgroundModifier())
    }

    /// A solid sheet or pushed-screen header, so content never shows behind it.
    public func solidNavigationBar(_ surface: Surface = .oat) -> some View {
        modifier(SolidNavigationBarModifier(surface: surface))
    }
}

private struct StatusBarBackgroundModifier: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            palette.paper
                .frame(height: 0)
                .background(palette.paper.ignoresSafeArea(edges: .top))
                .accessibilityHidden(true)
        }
    }
}

private struct SolidNavigationBarModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let surface: Surface

    func body(content: Content) -> some View {
        content
            .toolbarBackground(surface == .paper ? palette.paper : palette.oat, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

private struct PaperBackgroundModifier: ViewModifier {
    @Environment(\.palette) private var palette
    let surface: Surface

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                surface == .paper ? palette.paper : palette.oat
                PaperGrain()
            }
            .ignoresSafeArea()
        }
    }
}
