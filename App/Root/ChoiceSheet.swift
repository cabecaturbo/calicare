import Core
import SwiftUI

/// Bowel movement and Mood from the More menu: their choices as rows.
/// One tap logs and closes the sheet; the Logged line takes over.
enum LogChoice: String, Identifiable {
    case bowel, mood

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bowel: "Bowel movement"
        case .mood: "Mood"
        }
    }

    var type: LogType {
        switch self {
        case .bowel: .bowelMovement
        case .mood: .mood
        }
    }

    var options: [(title: String, value: LogValue)] {
        switch self {
        case .bowel: BowelMovement.allCases.map { ($0.title, .bowel($0)) }
        case .mood: Mood.allCases.map { ($0.title, .mood($0)) }
        }
    }
}

struct ChoiceSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TodayModel.self) private var model
    let choice: LogChoice

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(choice.options, id: \.title) { option in
                        Button {
                            dismiss()
                            Task { await model.log(choice.type, value: option.value) }
                        } label: {
                            Text(option.title)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(choice.title): \(option.title)")
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x2)
            }
            .paperBackground(.oat)
            .navigationTitle(choice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium])
    }
}
