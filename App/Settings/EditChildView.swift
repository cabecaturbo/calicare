import Core
import SwiftUI

/// Settings › a child: name, birth date, and color. Remove is here too, with a
/// confirmation; their logs stay in exports and reports.
struct EditChildView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let child: ChildInfo
    @State private var details: ChildDetails
    @State private var confirmingRemove = false
    @State private var problem: String?
    @State private var saving = false

    init(child: ChildInfo) {
        self.child = child
        _details = State(initialValue: ChildDetails(child))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                ChildDetailsForm(details: $details) { Task { await save() } }
                if let problem {
                    Text(problem)
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, Spacing.margin)
                }
                if canRemove {
                    Button("Remove \(child.name)") { confirmingRemove = true }
                        .buttonStyle(.textLink)
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)
                } else if model.householdSize > 1 {
                    Text("Removing a child in a shared family comes with the next update.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)
                }
            }
            .padding(.top, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!details.canSave || saving)
            }
        }
        .confirmationDialog("Remove \(child.name)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove \(child.name)") { Task { await remove() } }
        } message: {
            Text("\(child.name) leaves Today, widgets, and reminders. Their logs stay in exports.")
        }
    }

    /// The last child can't be removed, and a shared family needs the owner (not built yet).
    private var canRemove: Bool {
        model.children.count > 1 && model.householdSize <= 1
    }

    private func save() async {
        guard details.canSave, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            _ = try await details.save(updating: child.id)
            await model.load()
            dismiss()
        } catch {
            problem = "Couldn't save that just now. Please try again."
        }
    }

    private func remove() async {
        do {
            try await ChildStore(modelContainer: try CaliCareModelContainer.shared()).deleteChild(child.id)
            await LogChanges.didChange()
            await model.load()
            dismiss()
        } catch {
            problem = "Couldn't remove them just now. Please try again."
        }
    }
}
