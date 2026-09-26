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
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                if let child {
                    switcher(for: child)
                } else {
                    Text("Today")
                        .font(Typography.largeTitle)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            Spacer(minLength: 0)
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(palette.sageDark)
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
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
            HStack(alignment: .center, spacing: Spacing.xs) {
                if children.count > 1 {
                    ChildDot(color: ChildColor(tag: child.colorTag), size: 16)
                }
                Text(child.name)
                    .font(Typography.largeTitle)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.sageDark)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: TouchTarget.minimum)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(child.name)
        .accessibilityHint(children.count > 1 ? "Switch child, or add another." : "Add another child.")
        .accessibilityAddTraits(.isHeader)
    }
}
