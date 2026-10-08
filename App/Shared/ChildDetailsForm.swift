import Core
import SwiftUI

/// What a parent fills in for a child. Only the name is required.
struct ChildDetails {
    var name = ""
    var hasBirthDate = false
    var birthDate = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -2, to: .now) ?? .now
    var color: ChildColor?

    init() {}

    /// Starts from a saved child, for editing.
    init(_ child: ChildInfo) {
        name = child.name
        hasBirthDate = child.birthDate != nil
        if let born = child.birthDate { birthDate = born }
        color = ChildColor(tag: child.colorTag)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedName.isEmpty }

    /// Saves the child (or changes `updating`). A new child becomes the one
    /// quick logs go to; editing leaves the current child alone.
    func save(updating id: UUID? = nil) async throws -> ChildInfo {
        let store = ChildStore(modelContainer: try CaliCareModelContainer.shared())
        let born = hasBirthDate ? birthDate : nil
        let tag = (color ?? .standard).rawValue
        let child = if let id {
            try await store.updateChild(id, name: trimmedName, birthDate: born, colorTag: tag)
        } else {
            try await store.addChild(name: trimmedName, birthDate: born, colorTag: tag)
        }
        if id == nil { CurrentChildSetting().childID = child.id }
        await LogChanges.didChange()
        return child
    }
}

/// Full-width ledger rows: name, optional birth date, optional color.
struct ChildDetailsForm: View {
    @Environment(\.palette) private var palette
    @Binding var details: ChildDetails
    let onSubmit: () -> Void
    @FocusState private var nameFocused: Bool

    init(details: Binding<ChildDetails>, onSubmit: @escaping () -> Void = {}) {
        _details = details
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            LedgerRow {
                TextField("First name or nickname", text: $details.name)
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit(onSubmit)
                    .accessibilityLabel("Name")
            }

            LedgerRow {
                Toggle(isOn: $details.hasBirthDate.motion(.quick)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Birth date")
                            .textStyle(.control)
                            .foregroundStyle(palette.ink)
                        Text("Optional")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                }
                .tint(palette.accent)
            }

            if details.hasBirthDate {
                LedgerRow {
                    Text("Born")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                } trailing: {
                    DatePicker("Born", selection: $details.birthDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .tint(palette.accent)
                }
            }

            LedgerRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Color")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                    Text("You can skip this. It helps tell kids apart.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            } trailing: {
                colorChoices
            }
        }
        .onAppear { nameFocused = details.name.isEmpty }
    }

    private var colorChoices: some View {
        HStack(spacing: 0) {
            ForEach(ChildColor.allCases) { color in
                let selected = details.color == color
                Button {
                    details.color = selected ? nil : color
                } label: {
                    ChildDot(color: color, size: 20)
                        .padding(3)
                        .overlay(Circle().strokeBorder(selected ? palette.ink : .clear, lineWidth: 1))
                        .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
