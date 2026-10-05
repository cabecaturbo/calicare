import Core
import SwiftUI

/// A note for the current child. Opened from the medium widget's Note button.
struct NoteSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var text = ""
    @State private var saving = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextField("What happened?", text: $text, axis: .vertical)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .lineLimit(4...10)
                .focused($focused)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
                .frame(maxHeight: .infinity, alignment: .top)
                .paperBackground(.oat)
                .navigationTitle(model.child.map { "Note for \($0.name)" } ?? "Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                    }
                }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if await model.logNote(text) { dismiss() }
    }
}
