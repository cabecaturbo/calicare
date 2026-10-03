import Core
import SwiftUI
import UserNotifications

/// Info › Patch tests: "How do I patch test something new?" Plain steps,
/// the provider's words, one button to start, and tests under way.
struct PatchTestsScreen: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var starting = false
    @State private var checking: PatchTests.Test?

    private var tests: PatchTests { model.patchTests }

    var body: some View {
        InfoScreen(title: "Patch tests") {
            if let item = tests.planItem {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("What to do").textStyle(.section).foregroundStyle(palette.ink).accessibilityAddTraits(.isHeader)
                    Text(item.plainText ?? "Try a little of the new thing on a small spot first. Wait, then look at the skin.")
                        .textStyle(.body).foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("Your provider's words").textStyle(.section).foregroundStyle(palette.ink).accessibilityAddTraits(.isHeader)
                    Text("“\(item.providerWords)”")
                        .textStyle(.body).foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            Button("Start a patch test") { starting = true }
                .buttonStyle(.primary)
            if !tests.running.isEmpty || !tests.recent.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("Your tests").textStyle(.section).foregroundStyle(palette.ink).accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(tests.running) { test in
                            Button { checking = test } label: {
                                row(test.label, status(test), ready: test.isReady(at: .now))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Record how it looks.")
                        }
                        ForEach(tests.recent) { test in
                            row(test.label, test.result?.title ?? "", ready: false)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $starting) {
            StartPatchTestSheet(planLine: tests.planItem?.providerWords, wait: tests.wait)
                .nightAwarePalette()
        }
        .confirmationDialog("How does it look?", isPresented: checkingShowing, titleVisibility: .visible, presenting: checking) { test in
            ForEach(PatchResult.allCases, id: \.self) { result in
                Button(result.title) { Task { await model.setPatchResult(test, result) } }
            }
        } message: { test in
            Text(test.label)
        }
    }

    private var checkingShowing: Binding<Bool> {
        Binding(get: { checking != nil }, set: { if !$0 { checking = nil } })
    }

    /// "Check after 7:40 PM", "Check after 7:40 PM Thu", or "Ready to check".
    private func status(_ test: PatchTests.Test) -> String {
        guard let checkAt = test.checkAt, !test.isReady(at: .now) else { return "Ready to check" }
        let sameDay = Calendar.autoupdatingCurrent.isDateInToday(checkAt)
        return "Check after \(checkAt.formatted(sameDay ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).hour().minute()))"
    }

    private func row(_ title: String, _ detail: String, ready: Bool) -> some View {
        AdaptiveStack {
            Text(title).textStyle(.body).foregroundStyle(palette.ink)
            Spacer(minLength: 0)
            Text(detail).textStyle(.meta).foregroundStyle(ready ? palette.indigo : palette.graphite)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

/// What's being tested and where, then a reminder after the plan's wait.
private struct StartPatchTestSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let planLine: String?
    let wait: TimeInterval?
    @State private var what = ""
    @State private var spot: String

    init(planLine: String?, wait: TimeInterval?) {
        self.planLine = planLine
        self.wait = wait
        _spot = State(initialValue: planLine?.localizedCaseInsensitiveContains("forearm") == true ? "Inner forearm" : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("The product's name", text: $what)
                        .textStyle(.body)
                } header: {
                    FormHeader("What")
                }
                Section {
                    TextField("Where on the skin", text: $spot)
                        .textStyle(.body)
                } header: {
                    FormHeader("Where")
                } footer: {
                    Text(footnote).textStyle(.meta)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle("Start a patch test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let (what, spot) = (what, spot)
                        dismiss()
                        Task { await model.startPatchTest(what: what, where: spot) }
                    }
                    .disabled(what.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium, .large])
    }

    private var footnote: String {
        guard let wait else { return "Your plan doesn't say how long to wait, so there's no reminder." }
        let hours = Int(wait / 3600)
        let span = hours % 24 == 0 && hours >= 48 ? "\(hours / 24) days" : "\(hours) hours"
        return "We'll remind you to check it in \(span), as your plan says."
    }
}

/// The "check the patch test" reminder, one per test.
enum PatchReminder {
    private static func id(_ entry: LogEntry) -> String { "calicare.patch.\(entry.id.uuidString)" }

    static func schedule(for entry: LogEntry, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Time to check the patch test"
        content.body = entry.note ?? "Open Cali Care to record how it looks."
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: id(entry), content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for entry: LogEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(entry)])
    }
}
