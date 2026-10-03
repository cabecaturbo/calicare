import Core
import SwiftUI

/// One product: its name, kind and start date; stop it, mark it "never
/// again" with a reason, use it again, or remove it.
struct ProductEditor: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let product: ProductInfo
    @State private var name: String
    @State private var category: ProductCategory
    @State private var startedAt: Date
    @State private var askingReason = false
    @State private var reason = ""
    @State private var problem: String?

    init(product: ProductInfo) {
        self.product = product
        _name = State(initialValue: product.name)
        _category = State(initialValue: product.category)
        _startedAt = State(initialValue: product.startedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Kind", selection: $category) {
                        ForEach(ProductCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    DatePicker("Started", selection: $startedAt, in: ...Date.now, displayedComponents: .date)
                }
                if product.neverAgain {
                    Section("Never again") {
                        Text(product.reason ?? "No reason written.")
                        Button("Using it again") { Task { await act { try await $0.resume(product.id, from: .now) } } }
                    }
                } else if product.stoppedAt != nil {
                    Section {
                        Button("Using it again") { Task { await act { try await $0.resume(product.id, from: .now) } } }
                        Button("Never again") { askingReason = true }
                    }
                } else {
                    Section {
                        Button("Stopped using it") { Task { await act { try await $0.stop(product.id, on: .now) } } }
                        Button("Never again") { askingReason = true }
                    }
                }
                Section {
                    Button("Remove from the list") { Task { await act { try await $0.delete(product.id) } } }
                }
                if let problem { Text(problem) }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
            .alert("Never again", isPresented: $askingReason) {
                TextField("What happened? (optional)", text: $reason)
                Button("Cancel", role: .cancel) {}
                Button("Save") { Task { await act { [reason] in try await $0.neverAgain(product.id, reason: reason) } } }
            } message: {
                Text("In your own words, for next time.")
            }
        }
        .tint(palette.indigo)
    }

    private func save() async {
        guard name != product.name || category != product.category || startedAt != product.startedAt else {
            dismiss()
            return
        }
        await act { [name, category, startedAt] in try await $0.edit(product.id, name: name, category: category, startedAt: startedAt) }
    }

    private func act(_ change: @Sendable (ProductStore) async throws -> Void) async {
        do {
            try await change(ProductStore(modelContainer: CaliCareModelContainer.shared()))
            await LogChanges.didChange()
            dismiss()
        } catch ProductStoreError.emptyName {
            problem = "A product needs a name."
        } catch {
            problem = "Couldn't save that change. Please try again."
        }
    }
}
