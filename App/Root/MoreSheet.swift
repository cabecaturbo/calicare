import Core
import SwiftUI

/// "More to log": Flare, Bowel movement, Mood, Note, as a native sheet. Picking
/// one closes the sheet first, then logs or opens its own sheet.
struct MoreSheet: View {
    enum Choice {
        case flare, bowel, mood, note
    }

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let onPick: (Choice) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                row("Flare", .flare)
                row("Bowel movement", .bowel)
                row("Mood", .mood)
                row("Note", .note)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x2)
            .paperBackground()
            .navigationTitle("More to log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium])
    }

    private func row(_ title: String, _ choice: Choice) -> some View {
        Button {
            onPick(choice)
            dismiss()
        } label: {
            Text(title)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, minHeight: Size.row(isNight: palette.isNight), alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
    }
}
