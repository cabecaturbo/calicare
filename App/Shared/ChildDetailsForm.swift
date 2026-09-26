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
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Name")
                    .font(Typography.headline)
                    .foregroundStyle(palette.ink)
                TextField("First name or nickname", text: $details.name)
                    .font(Typography.body)
                    .foregroundStyle(palette.ink)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit(onSubmit)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: TouchTarget.night)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: $details.hasBirthDate.animation()) {
                    Text("Add birth date")
                        .font(Typography.body)
                        .foregroundStyle(palette.ink)
                }
                .tint(palette.accent)
                .frame(minHeight: TouchTarget.minimum)

                if details.hasBirthDate {
                    DatePicker("Birth date", selection: $details.birthDate, in: ...Date.now, displayedComponents: .date)
                        .font(Typography.body)
                        .foregroundStyle(palette.ink)
                        .frame(minHeight: TouchTarget.minimum)
                }
                Text("Optional")
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Color")
                    .font(Typography.headline)
                    .foregroundStyle(palette.ink)
                colorChoices
                Text("Optional. Helps tell children apart.")
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
            }
        }
        .onAppear { nameFocused = details.name.isEmpty }
    }

    private var colorChoices: some View {
        HStack(spacing: Spacing.s) {
            ForEach(ChildColor.allCases) { color in
                let selected = details.color == color
                Button {
                    details.color = selected ? nil : color
                } label: {
                    ChildDot(color: color, size: 30)
                        .padding(Spacing.xxs)
                        .overlay(Circle().strokeBorder(selected ? palette.ink : .clear, lineWidth: 2))
                        .frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
