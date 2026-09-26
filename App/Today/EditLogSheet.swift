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
            Form {
                Section {
                    DatePicker("Time", selection: $timestamp, in: ...max(Date.now, entry.timestamp))
                        .font(Typography.body)
                        .frame(minHeight: TouchTarget.minimum)
                }
                .listRowBackground(palette.card)

                if !options.isEmpty {
                    Section {
                        Picker("Kind", selection: $value) {
                            ForEach(options, id: \.self) { option in
                                Text(option.title)
                                    .font(Typography.body)
                                    .tag(option.value)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("Kind")
                    }
                    .listRowBackground(palette.card)
                }

                Section {
                    TextField(entry.type == .note ? "Write a note" : "Add a note", text: $note, axis: .vertical)
                        .font(Typography.body)
                        .lineLimit(1...6)
                        .frame(minHeight: TouchTarget.minimum)
                } header: {
                    Text("Note")
                }
                .listRowBackground(palette.card)

                Section {
                    Button {
                        confirmingDelete = true
                    } label: {
                        Label("Delete this log", systemImage: "trash")
                            .font(Typography.button)
                            .foregroundStyle(palette.clay)
                            .frame(minHeight: TouchTarget.minimum)
                    }
                } footer: {
                    Text("Deleted logs disappear from Today, widgets, and reports.")
                }
                .listRowBackground(palette.card)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
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
        .tint(palette.accent)
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
        case .itchEpisode, .flare, .note:
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
