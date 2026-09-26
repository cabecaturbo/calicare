import SwiftUI

extension View {
    /// Switches between the day and night palettes automatically (8 PM – 7 AM).
    public func nightAwarePalette() -> some View {
        modifier(NightAwarePaletteModifier())
    }

    /// White (day) or warm dark (night) card with 18pt corners.
    public func cardStyle() -> some View {
        modifier(CardStyle())
    }
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

private struct CardStyle: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
