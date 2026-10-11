import Core
import SwiftUI

/// Plan's Provider: the next visit (or when the plan says to follow up),
/// messages left of the plan's allowance, and the last visit.
struct ProviderSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let tracker: ProviderTracker
    @State private var addingVisit = false
    @State private var askingFor: VisitInfo?

    private let day = Date.FormatStyle.dateTime.month(.abbreviated).day()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Provider")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                if let next = tracker.nextVisit {
                    // Tap to write down questions; they go on the doctor report.
                    Button { askingFor = next } label: {
                        row("Next visit", next.date.formatted(day) + (next.questions == nil ? "" : " · questions"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Questions for the visit.")
                } else if let window = tracker.followUp {
                    row("Follow-up visit", "\(window.from.formatted(day)) – \(window.to.formatted(day))")
                }
                if let messages = tracker.messages {
                    Button { Task { await model.logProviderMessage() } } label: {
                        row("Messages", "\(messages.left) of \(messages.total) left" + (messages.until.map { " · until \($0.formatted(day))" } ?? ""))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Logs one message sent to the provider.")
                }
                if let last = tracker.lastVisit {
                    row("Last visit", last.date.formatted(day))
                }
            }
            Button("Add a visit") { addingVisit = true }
                .buttonStyle(.textLink)
            if let child = model.child {
                NavigationLink {
                    JournalExportView(child: child, from: model.activePlan?.startedAt)
                } label: {
                    Text("Journal for your provider").textStyle(.body).foregroundStyle(palette.accent)
                }
                .frame(minHeight: Size.touchTarget)
            }
        }
        .sheet(item: $askingFor) { visit in
            VisitQuestionsSheet(visit: visit)
                .nightAwarePalette()
        }
        .sheet(isPresented: $addingVisit) {
            AddVisitSheet(provider: model.activePlan?.provider ?? tracker.lastVisit?.provider ?? "")
                .nightAwarePalette()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        AdaptiveStack {
            Text(title).textStyle(.body).foregroundStyle(palette.ink)
            Spacer(minLength: 0)
            Text(value).textStyle(.meta).foregroundStyle(palette.graphite)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

/// A visit, past or booked: the date, who, and an optional note.
private struct AddVisitSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var date = Date.now
    @State private var provider: String
    @State private var notes = ""
    @State private var questions = ""

    init(provider: String) {
        _provider = State(initialValue: provider)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date)
                        .textStyle(.body)
                } header: {
                    FormHeader("When")
                }
                Section {
                    TextField("Provider", text: $provider)
                        .textStyle(.body)
                } header: {
                    FormHeader("Who")
                }
                Section {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .textStyle(.body)
                } header: {
                    FormHeader("Note")
                }
                Section {
                    TextField("Optional", text: $questions, axis: .vertical)
                        .textStyle(.body)
                } header: {
                    FormHeader("Questions for the visit")
                } footer: {
                    Text("They show on the doctor report.").textStyle(.meta)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle("Add a visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let (date, provider, notes, questions) = (date, provider, notes, questions)
                        dismiss()
                        Task { await model.addVisit(date: date, provider: provider, notes: notes, questions: questions) }
                    }
                }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
    }
}

/// The next visit's "Questions for the visit", for the doctor report.
private struct VisitQuestionsSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let visit: VisitInfo
    @State private var questions: String

    init(visit: VisitInfo) {
        self.visit = visit
        _questions = State(initialValue: visit.questions ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to ask?", text: $questions, axis: .vertical)
                        .textStyle(.body)
                        .lineLimit(3...8)
                } header: {
                    FormHeader("Questions for the visit")
                } footer: {
                    Text("They show on the doctor report.").textStyle(.meta)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle(visit.date.formatted(.dateTime.month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let text = questions
                        dismiss()
                        Task { await model.setQuestions(text, visit: visit.id) }
                    }
                }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
    }
}
