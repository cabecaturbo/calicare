import Core
import SwiftUI

/// The header every tab shares: the tab's name, then the child switcher and the
/// Settings gear on the same row, and one plain "why" line under it.
struct AppHeader: View {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell
    let title: String
    /// Why this screen helps: "Tap how Cal's skin is doing."
    var why: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            HStack(spacing: Spacing.x4) {
                Text(title)
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                ChildSwitcher(style: .navigationBar)
                Button {
                    shell.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.regular))
                        .foregroundStyle(palette.graphite)
                        .frame(width: Size.touchTarget, height: Size.touchTarget)
                        .overlay(Circle().strokeBorder(palette.hairline, lineWidth: Rule.width))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .frame(minHeight: Size.touchTarget)
            if let why {
                Text(why)
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x2)
    }
}

/// The one big statement under the header, and its single smaller line.
struct BigStatement: View {
    @Environment(\.palette) private var palette
    let text: String
    var line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(text)
                .textStyle(.statement)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(line)
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
