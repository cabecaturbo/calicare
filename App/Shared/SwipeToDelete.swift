import Core
import SwiftUI

/// Swipe a row left to show Delete; swipe far to delete at once. Rows live in a
/// ScrollView (not a List), so this is a small drag rather than `swipeActions`.
/// Delete is ink on oat: never red.
struct SwipeToDelete<Content: View>: View {
    @Environment(\.palette) private var palette
    let onDelete: () -> Void
    @ViewBuilder let content: Content
    @State private var offset: CGFloat = 0
    /// Where the row sat when the drag began: closed, or showing Delete.
    @State private var resting: CGFloat = 0
    /// While dragging (or open), the row's own tap is off so a swipe never opens it.
    @State private var dragging = false

    private let revealed: CGFloat = -88
    private let fullSwipe: CGFloat = -180

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button(action: delete) {
                    Text("Delete")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .frame(width: -revealed)
                        .frame(maxHeight: .infinity)
                        .background(palette.oat)
                }
                .buttonStyle(.plain)
            }
            content
                .disabled(dragging || offset != 0)
                .background(palette.paper)
                .offset(x: offset)
                .overlay {
                    // Tapping an open row closes it.
                    if offset != 0, !dragging {
                        Color.clear.contentShape(Rectangle()).padding(.trailing, -revealed)
                            .onTapGesture { withMotion(.quick) { offset = 0; resting = 0 } }
                    }
                }
        }
        .simultaneousGesture(drag)
        .clipped()
        .accessibilityAction(named: "Delete", onDelete)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragging = true
                offset = min(0, resting + value.translation.width)
            }
            .onEnded { value in
                withMotion(.quick) {
                    if offset < fullSwipe {
                        delete()
                    } else {
                        offset = offset < revealed / 2 ? revealed : 0
                    }
                    resting = offset
                    dragging = false
                }
            }
    }

    private func delete() {
        offset = 0
        resting = 0
        onDelete()
    }
}
