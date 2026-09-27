import Core
import SwiftUI

/// What a parent fills in for a child. Only the name is required.
struct ChildDetails {
    var name = ""
    var hasBirthDate = false
    var birthDate = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -2, to: .now) ?? .now
    var color: ChildColor?

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !trimmedName.isEmpty }

    /// Saves the child and makes them the one quick logs go to.
    func save() async throws -> ChildInfo {
        let store = ChildStore(modelContainer: try CaliCareModelContainer.shared())
        let child = try await store.addChild(
            name: trimmedName,
            birthDate: hasBirthDate ? birthDate : nil,
            colorTag: (color ?? .standard).rawValue
        )
        CurrentChildSetting().childID = child.id
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
                Toggle(isOn: $details.hasBirthDate.animation(.easeOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Birth date")
                            .textStyle(.control)
                            .foregroundStyle(palette.ink)
                        Text("Optional")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                    }
                }
                .tint(palette.indigo)
            }

            if details.hasBirthDate {
                LedgerRow {
                    Text("Born")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                } trailing: {
                    DatePicker("Born", selection: $details.birthDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .tint(palette.indigo)
                }
            }

            LedgerRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Color")
                        .textStyle(.control)
                        .foregroundStyle(palette.ink)
                    Text("Optional. Helps tell children apart.")
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
