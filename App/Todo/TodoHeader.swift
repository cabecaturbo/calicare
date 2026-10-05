import Core
import SwiftUI

/// To do's header (canvas "HeaderV2"): the title in serif on the left, the
/// child switcher and the Settings gear on the right, then one why-line.
struct TodoHeader: View {
    @Environment(\.palette) private var palette
    @Environment(Shell.self) private var shell
    let why: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            HStack(spacing: Spacing.x3) {
                Text("To do")
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
                .padding(.leading, Spacing.x1)
            }
            .frame(minHeight: Size.touchTarget)
            Text(why)
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.x2)
    }
}
