import SwiftUI

/// Ink fill, paper text, 4pt corners, full width. One per screen.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        @Environment(\.palette) private var palette
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .textStyle(.control)
                .foregroundStyle(palette.paper)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.x4)
                .padding(.vertical, Spacing.x3)
                .frame(maxWidth: .infinity, minHeight: Size.button(isNight: palette.isNight))
                .background(palette.ink, in: RoundedRectangle(cornerRadius: Corner.control))
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: Corner.control))
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}

/// No fill, ink text, 0.5pt ink outline.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        @Environment(\.palette) private var palette
        let configuration: Configuration

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Corner.control)
            configuration.label
                .textStyle(.control)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.x4)
                .padding(.vertical, Spacing.x3)
                .frame(maxWidth: .infinity, minHeight: Size.button(isNight: palette.isNight))
                .background(configuration.isPressed ? palette.oat : .clear, in: shape)
                .overlay(shape.strokeBorder(palette.ink, lineWidth: Rule.width))
                .contentShape(shape)
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}

/// Indigo words, like "Undo" or "Show me again". Still at least 44pt to tap.
public struct TextLinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        @Environment(\.palette) private var palette
        let configuration: Configuration

        var body: some View {
            configuration.label
                .textStyle(.control)
                .foregroundStyle(palette.indigo)
                .opacity(configuration.isPressed ? 0.6 : 1)
                .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
                .contentShape(Rectangle())
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    public static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    public static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }
}
