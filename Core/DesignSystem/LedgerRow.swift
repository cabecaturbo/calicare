import SwiftUI

/// The one layout primitive: full width on paper, label left, value or action
/// right, a 0.5pt hairline below. 56pt tall by day, 72pt at night. At the
/// largest text sizes the trailing side moves under the label so nothing clips.
public struct LedgerRow<Label: View, Trailing: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    private let label: Label
    private let trailing: Trailing

    public init(@ViewBuilder label: () -> Label, @ViewBuilder trailing: () -> Trailing) {
        self.label = label()
        self.trailing = trailing()
    }

    public var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.x1))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.x4))
        layout {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            trailing
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.x2)
        .frame(maxWidth: .infinity, minHeight: Size.row(isNight: palette.isNight), alignment: .leading)
        .overlay(alignment: .bottom) { Hairline() }
        .contentShape(Rectangle())
    }
}

extension LedgerRow where Trailing == EmptyView {
    public init(@ViewBuilder label: () -> Label) {
        self.init(label: label, trailing: { EmptyView() })
    }
}

/// Wraps a row in a button whose tap fills it with oat, like ink soaking into
/// paper. No scale, no bounce. `isSelected` keeps the fill.
public struct LedgerButtonStyle: ButtonStyle {
    let isSelected: Bool

    public init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        Filled(label: configuration.label, isFilled: configuration.isPressed || isSelected,
               isPressed: configuration.isPressed)
    }

    private struct Filled<Content: View>: View {
        @Environment(\.palette) private var palette
        let label: Content
        let isFilled: Bool
        let isPressed: Bool

        var body: some View {
            label
                .background(isFilled ? palette.oat : .clear)
                .motion(.quick, value: isFilled)
                .pressable(isPressed)
        }
    }
}

extension ButtonStyle where Self == LedgerButtonStyle {
    public static var ledger: LedgerButtonStyle { LedgerButtonStyle() }

    public static func ledger(isSelected: Bool) -> LedgerButtonStyle {
        LedgerButtonStyle(isSelected: isSelected)
    }
}

/// A title, a rule, then rows. Sections sit 40pt apart.
public struct LedgerSection<Content: View>: View {
    @Environment(\.palette) private var palette
    private let title: String?
    private let footnote: String?
    private let content: Content

    public init(_ title: String? = nil, footnote: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.bottom, Spacing.x2)
                    .accessibilityAddTraits(.isHeader)
            }
            Hairline()
            content
            if let footnote {
                Text(footnote)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A 0.5pt rule on the ledger's left and right edges.
public struct Hairline: View {
    @Environment(\.palette) private var palette
    private let inset: CGFloat

    public init(inset: CGFloat = Spacing.margin) {
        self.inset = inset
    }

    public var body: some View {
        palette.hairline
            .frame(height: Rule.width)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}
