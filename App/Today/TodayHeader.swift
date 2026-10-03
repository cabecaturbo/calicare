import Core
import SwiftUI

/// Today's date, then the child's name in display type (tap to switch or add a child).
/// Settings lives in the navigation bar, like every tab.
struct TodayHeader: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
            ChildSwitcher(style: .display)
        }
    }
}
