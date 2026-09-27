import Core
import SwiftUI

/// The child's name; tap to switch child or add one. Display type on Today,
/// a small row-style name in the navigation bar on Plan and Progress.
struct ChildSwitcher: View {
    enum Style {
        case display, navigationBar
    }

    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @Environment(Shell.self) private var shell
    let style: Style

    var body: some View {
        if let child = model.child {
            Menu {
                Section("Log for") {
                    ForEach(model.children) { option in
                        Button {
                            Task { await model.select(option.id) }
                        } label: {
                            if option.id == child.id {
                                Label(option.name, systemImage: "checkmark")
                            } else {
                                Text(option.name)
                            }
                        }
                    }
                }
                Button {
                    shell.showingAddChild = true
                } label: {
                    Label("Add a child", systemImage: "plus")
                }
            } label: {
                label(for: child)
            }
            .accessibilityLabel(child.name)
            .accessibilityHint(model.children.count > 1 ? "Switch child, or add another." : "Add another child.")
            .accessibilityAddTraits(.isHeader)
        } else if style == .display {
            Text("Today")
                .textStyle(.display)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private func label(for child: ChildInfo) -> some View {
        switch style {
        case .display:
            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                if model.children.count > 1 {
                    ChildDot(color: ChildColor(tag: child.colorTag), size: 12)
                }
                Text(child.name)
                    .textStyle(.display)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                chevron
            }
            .frame(minHeight: Size.touchTarget)
            .contentShape(Rectangle())
        case .navigationBar:
            HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                Text(child.name)
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                chevron
            }
            .frame(minHeight: Size.touchTarget)
            .contentShape(Rectangle())
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.regular))
            .foregroundStyle(palette.graphite)
            .accessibilityHidden(true)
    }
}
