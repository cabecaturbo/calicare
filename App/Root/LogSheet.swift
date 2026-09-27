import Core
import SwiftUI

/// "Log…" from the quick log bar: the same rows as Today's Log section.
/// One tap logs and closes the sheet; the confirmation line takes over.
struct LogSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TodayModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                LogButtons(isDaytime: model.isDaytime, entries: model.entries, lastNight: model.lastNight) { type, value in
                    dismiss()
                    Task { await model.log(type, value: value) }
                }
                .padding(.vertical, Spacing.x4)
            }
            .paperBackground(.oat)
            .navigationTitle(model.child.map { "Log for \($0.name)" } ?? "Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
}
