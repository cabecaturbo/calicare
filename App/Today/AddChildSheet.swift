import Core
import SwiftUI

/// Add another child from the switcher. They become the current child.
struct AddChildSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var details = ChildDetails()
    @State private var problem: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ChildDetailsForm(details: $details) { Task { await save() } }
                    if let problem {
                        Text(problem)
                            .font(Typography.callout)
                            .foregroundStyle(palette.clay)
                    }
                }
                .padding(Spacing.l)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Add a child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(!details.canSave || saving)
                }
            }
        }
        .tint(palette.accent)
    }

    private func save() async {
        guard details.canSave, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            _ = try await details.save()
            dismiss()
        } catch {
            problem = "Couldn't add them just now. Please try again."
        }
    }
}
