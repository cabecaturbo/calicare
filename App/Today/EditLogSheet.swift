import Core
import SwiftUI

/// Change a log's time, kind, or note, or delete it (soft delete).
struct EditLogSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let entry: LogEntry
    let model: TodayModel
    @State private var timestamp: Date
    @State private var value: LogValue?
    @State private var note: String
    @State private var confirmingDelete = false
    @State private var saving = false

    init(entry: LogEntry, model: TodayModel) {
        self.entry = entry
        self.model = model
        _timestamp = State(initialValue: entry.timestamp)
        _value = State(initialValue: entry.value)
        _note = State(initialValue: entry.note ?? "")
    }

    private struct Option: Hashable {
        let title: String
        let value: LogValue?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    LedgerSection {
                        LedgerRow {
                            Text("Time")
                                .textStyle(.control)
                                .foregroundStyle(palette.ink)
                        } trailing: {
                            DatePicker("Time", selection: $timestamp, in: ...max(Date.now, entry.timestamp))
                                .labelsHidden()
                                .tint(palette.indigo)
                        }
                    }

                    if !options.isEmpty {
                        LedgerSection("Kind") {
                            ForEach(options, id: \.self) { option in
                                kindRow(option)
                            }
                        }
                    }

                    LedgerSection("Note") {
                        LedgerRow {
                            TextField(entry.type == .note ? "Write a note" : "Add a note", text: $note, axis: .vertical)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .lineLimit(1...6)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Button("Delete this log") { confirmingDelete = true }
                            .buttonStyle(.secondary)
                        Text("Deleted logs disappear from Today, widgets, and reports.")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Spacing.margin)
                }
                .padding(.vertical, Spacing.margin)
            }
            .paperBackground(.oat)
            .navigationTitle(model.title(for: entry))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave || saving)
                }
            }
            .confirmationDialog("Delete this log?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete log") {
                    Task {
                        await model.delete(entry)
                        dismiss()
                    }
                }
                Button("Keep it", role: .cancel) {}
            }
        }
        .tint(palette.indigo)
    }

    private func kindRow(_ option: Option) -> some View {
        let selected = option.value == value
        return Button {
            value = option.value
        } label: {
            LedgerRow {
                Text(option.title)
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            } trailing: {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.regular))
                        .foregroundStyle(palette.indigo)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var canSave: Bool {
        entry.type != .note || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var options: [Option] {
        let notSet = Option(title: "Not set", value: nil)
        switch entry.type {
        case .nightRating:
            return NightRating.allCases.map { Option(title: $0.title, value: .night($0)) }
        case .bowelMovement:
            return [notSet] + BowelMovement.allCases.map { Option(title: $0.title, value: .bowel($0)) }
        case .mood:
            return Mood.allCases.map { Option(title: $0.title, value: .mood($0)) }
        case .routineDone:
            return [notSet] + RoutineTime.allCases.map { Option(title: $0.title, value: .routine($0)) }
        case .skinToday:
            return SkinToday.allCases.map { Option(title: $0.title, value: .skin($0)) }
        case .patchTest:
            return [notSet] + PatchResult.allCases.map { Option(title: $0.title, value: .patch($0)) }
        case .itchEpisode, .flare, .note, .bath, .supplement:
            return []
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if await model.update(entry, value: value, note: note, timestamp: timestamp) {
            dismiss()
        }
    }
}
