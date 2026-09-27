import Core
import SwiftUI

/// Today's date, the child's name (tap to switch or add a child), and Settings.
struct TodayHeader: View {
    @Environment(\.palette) private var palette
    let children: [ChildInfo]
    let child: ChildInfo?
    let onSelect: (UUID) -> Void
    let onAddChild: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Spacer(minLength: Spacing.x4)
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.regular))
                        .foregroundStyle(palette.graphite)
                        .frame(width: Size.touchTarget, height: Size.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            if let child {
                switcher(for: child)
            } else {
                Text("Today")
                    .textStyle(.display)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func switcher(for child: ChildInfo) -> some View {
        Menu {
            Section("Log for") {
                ForEach(children) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        if option.id == child.id {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                }
            }
            Button(action: onAddChild) {
                Label("Add a child", systemImage: "plus")
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                if children.count > 1 {
                    ChildDot(color: ChildColor(tag: child.colorTag), size: 12)
                }
                Text(child.name)
                    .textStyle(.display)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(palette.graphite)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Size.touchTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(child.name)
        .accessibilityHint(children.count > 1 ? "Switch child, or add another." : "Add another child.")
        .accessibilityAddTraits(.isHeader)
    }
}
