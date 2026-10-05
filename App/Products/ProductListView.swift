import Core
import SwiftUI

/// Plan › Products: what the child uses (moisturizers, washes, laundry,
/// clothing), since when, and the "never again" list in the parent's words.
struct ProductListView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var newName = ""
    @State private var newCategory: ProductCategory = .moisturizer
    @State private var editing: ProductInfo?
    @State private var problem: String?

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add a product", text: $newName)
                        .textStyle(.body)
                        .submitLabel(.done)
                        .onSubmit { Task { await add() } }
                        .onChange(of: newName) { _, name in
                            if let guess = ProductCategory.guess(from: name) { newCategory = guess }
                        }
                    Picker("Kind", selection: $newCategory) {
                        ForEach(ProductCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                }
                .listRowBackground(palette.paper)
                if let problem {
                    Text(problem).textStyle(.meta).foregroundStyle(palette.graphite).listRowBackground(palette.paper)
                }
            } footer: {
                if model.products.isEmpty {
                    Text("Add what touches the skin: creams, washes, laundry soap, clothes. Starting and stopping shows up in Progress › Changes.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            }
            group("In use", model.products.filter(\.inUse))
            group("Stopped", model.products.filter { !$0.inUse && !$0.neverAgain })
            group("Never again", model.products.filter(\.neverAgain))
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.inline)
        .tint(palette.accent)
        .sheet(item: $editing, onDismiss: { Task { await model.load() } }) { product in
            ProductEditor(product: product)
                .nightAwarePalette()
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ products: [ProductInfo]) -> some View {
        if !products.isEmpty {
            Section {
                ForEach(products) { product in
                    Button { editing = product } label: { ProductRow(product: product) }
                        .buttonStyle(.plain)
                        .listRowBackground(palette.paper)
                }
            } header: {
                Text("\(title) · \(products.count)")
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .textCase(nil)
            }
        }
    }

    private func add() async {
        guard let child = model.child, !newName.trimmingCharacters(in: .whitespaces).isEmpty,
              let container = try? CaliCareModelContainer.shared()
        else { return }
        do {
            try await ProductStore(modelContainer: container).add(name: newName, category: newCategory,
                                                                  startedAt: .now, child: child.id)
            newName = ""
            newCategory = .moisturizer
            problem = nil
            await model.load()
            Task { await LogChanges.didChange() }
        } catch {
            problem = "Couldn't add that. Please try again."
        }
    }
}

/// One product: its name, kind and dates, and the parent's reason when it's "never again".
private struct ProductRow: View {
    @Environment(\.palette) private var palette
    let product: ProductInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.name).textStyle(.body).foregroundStyle(palette.ink)
            Text(detail).textStyle(.meta).foregroundStyle(palette.graphite)
            if product.neverAgain, let reason = product.reason {
                Text("“\(reason)”").textStyle(.meta).foregroundStyle(palette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "Moisturizer · since Sep 3", or "Wash · Sep 3 – Sep 20".
    private var detail: String {
        let date = Date.FormatStyle.dateTime.month(.abbreviated).day()
        let when = product.stoppedAt.map { "\(product.startedAt.formatted(date)) – \($0.formatted(date))" }
            ?? "since \(product.startedAt.formatted(date))"
        return "\(product.category.title) · \(when)"
    }
}
