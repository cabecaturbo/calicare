import Core
import SwiftUI

/// Today's (or tonight's) logs, newest first. Tap to change one; swipe left to
/// delete (Undo shows in the Logged line).
struct TodayLogsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let isNight: Bool
    @State private var editing: LogEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if model.entries.isEmpty {
                        Text(isNight ? "Nothing logged tonight." : "Nothing logged today.")
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.x4)
                    }
                    ForEach(model.entries) { entry in
                        SwipeToDelete { Task { await model.deleteWithUndo(entry) } } content: {
                            Button { editing = entry } label: {
                                HStack {
                                    Text(model.title(for: entry))
                                        .textStyle(.body)
                                        .foregroundStyle(palette.ink)
                                    Spacer()
                                    Text([model.time(entry.timestamp), model.byline(for: entry)].compactMap { $0 }.joined(separator: " · "))
                                        .textStyle(.meta)
                                        .foregroundStyle(palette.graphite)
                                }
                                .frame(minHeight: Size.row(isNight: palette.isNight))
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Change it, or swipe left to delete.")
                        }
                    }
                }
                .padding(.horizontal, Spacing.margin)
            }
            .paperBackground()
            .navigationTitle(isNight ? "Tonight’s logs" : "Today’s logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { entry in
                EditLogSheet(entry: entry, model: model)
                    .presentationDetents([.medium, .large])
                    .nightAwarePalette()
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium, .large])
    }
}
