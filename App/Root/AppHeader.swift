import Core
import SwiftUI

/// The header every tab shares (DESIGN.md §5): the child switcher and the
/// Settings gear on top, then the tab's name as the display title.
struct AppHeader: View {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ChildSwitcher(style: .navigationBar)
                Spacer(minLength: Spacing.x4)
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
            Text(title)
                .textStyle(.display)
                .foregroundStyle(palette.ink)
                .padding(.top, Spacing.x2)
                .accessibilityAddTraits(.isHeader)
            if let caption {
                Text(caption)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .padding(.top, Spacing.x1)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x2)
    }
}
