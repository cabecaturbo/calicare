import Core
import SwiftUI

/// Morning, Afternoon, and Bedtime as cards: an icon, the name, "2 of 5" (or
/// Done), and a thin bar. The shown part is outlined in ink on paper; tapping
/// another shows its list. Stacks at the largest text sizes.
struct DayParts: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let blocks: [TodoDay.Block]
    let shown: TodoBlock?
    let onPick: (TodoBlock) -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.x2))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.x2))
        layout {
            ForEach(blocks) { block in
                DayPartCard(block: block, isShown: block.block == shown) { onPick(block.block) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Parts of the day")
    }
}

private struct DayPartCard: View {
    @Environment(\.palette) private var palette
    let block: TodoDay.Block
    let isShown: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isShown ? palette.indigo : palette.graphite)
                    .frame(height: 20)
                Text(block.block.title)
                    .textStyle(.label)
                    .foregroundStyle(palette.ink)
                HStack(spacing: Spacing.x1) {
                    if block.isDone {
                        Image(systemName: "checkmark").font(.caption2.weight(.bold))
                    }
                    Text(block.status).textStyle(.meta)
                }
                .foregroundStyle(palette.graphite)
                Spacer(minLength: 0)
                Capsule()
                    .fill(palette.hairline)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(palette.indigo).frame(width: proxy.size.width * block.fraction)
                        }
                    }
                    .padding(.top, Spacing.x1)
            }
            .padding(EdgeInsets(top: Spacing.x3, leading: Spacing.x3, bottom: Spacing.x2, trailing: Spacing.x3))
            .frame(maxWidth: .infinity, minHeight: 84, maxHeight: .infinity, alignment: .topLeading)
            .background(isShown ? palette.paper : palette.oat, in: RoundedRectangle(cornerRadius: Corner.tight))
            .overlay(
                RoundedRectangle(cornerRadius: Corner.tight)
                    .strokeBorder(isShown ? palette.ink : palette.hairline, lineWidth: isShown ? 1.5 : Rule.width)
            )
            .contentShape(RoundedRectangle(cornerRadius: Corner.tight))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.block.title). \(block.status).")
        .accessibilityAddTraits(isShown ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isShown ? "" : "Shows this list.")
    }

    private var symbol: String {
        switch block.block {
        case .morning: "sunrise"
        case .afternoon: "sun.max"
        case .bedtime: "moon"
        }
    }
}
