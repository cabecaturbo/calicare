import Core
import SwiftUI
import UserNotifications

/// Food list › Leftovers: cooked batches with the days the parent chose,
/// soonest first. Used, Freeze, or Toss.
struct LeftoversSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    /// Sheets live on the screen, not on a List section (they don't always present there).
    let onAdd: () -> Void
    let onFreeze: (LeftoverBatch) -> Void

    var body: some View {
        Section {
            ForEach(model.batches) { batch in
                row(batch)
                    .swipeActions(edge: .trailing) {
                        Button("Used") { Task { await model.finishBatch(batch) } }.tint(palette.indigo)
                        if batch.place == .fridge {
                            Button("Freeze") { onFreeze(batch) }.tint(palette.graphite)
                        }
                        Button("Toss") { Task { await model.finishBatch(batch) } }.tint(palette.graphite)
                    }
                    .listRowBackground(palette.paper)
            }
            Button("Add a cooked batch", action: onAdd)
                .buttonStyle(.textLink)
                .listRowBackground(palette.paper)
        } header: {
            Text("Leftovers").textStyle(.section).foregroundStyle(palette.ink).textCase(nil)
        } footer: {
            if !model.batches.isEmpty {
                Text("Swipe left for Used, Freeze, or Toss.").textStyle(.meta).foregroundStyle(palette.graphite)
            }
        }
    }

    private func row(_ batch: LeftoverBatch) -> some View {
        let left = batch.daysLeft(at: .now)
        let when = left < 0 ? "Past its days" : left == 0 ? "Last day today" : left == 1 ? "Until tomorrow" :
            "Until \(batch.useBy.formatted(.dateTime.weekday(.abbreviated)))"
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(batch.name).textStyle(.body).foregroundStyle(palette.ink)
                Text(batch.place == .freezer ? "Freezer" : "Fridge").textStyle(.meta).foregroundStyle(palette.graphite)
            }
            Spacer()
            Text(when).textStyle(.meta).foregroundStyle(left <= 0 ? palette.ochre : palette.graphite)
        }
    }
}

/// What was cooked, where it went, and how many days to keep it.
struct AddBatchSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @State private var name = ""
    @State private var place: BatchPlace = .fridge
    @State private var days = 3

    var body: some View {
        NavigationStack {
            Form {
                TextField("What did you cook?", text: $name)
                Picker("Where", selection: $place) {
                    Text("Fridge").tag(BatchPlace.fridge)
                    Text("Freezer").tag(BatchPlace.freezer)
                }
                .pickerStyle(.segmented)
                .onChange(of: place) { _, new in days = new == .freezer ? 30 : 3 }
                Section {
                    Stepper("Keep \(days) day\(days == 1 ? "" : "s")", value: $days, in: 1...(place == .freezer ? 180 : 14))
                } footer: {
                    Text("You'll get a reminder on the last day.")
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .navigationTitle("Cooked batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let (name, place, days) = (name, place, days)
                        dismiss()
                        Task { await model.addBatch(name, place: place, days: days) }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium])
    }
}

/// "Last day for the chicken rice", one per batch.
enum BatchReminder {
    private static func id(_ batch: LeftoverBatch) -> String { "calicare.batch.\(batch.id.uuidString)" }

    static func schedule(_ batch: LeftoverBatch) async {
        if await NotificationPermission.status() == .notDetermined { _ = await NotificationPermission.request() }
        let content = UNMutableNotificationContent()
        content.title = "Last day for the \(batch.name.lowercased())"
        content.body = batch.place == .freezer ? "From the freezer." : "Use it or freeze it today."
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: batch.useBy) ?? batch.useBy
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: max(morning, .now.addingTimeInterval(60)))
        let request = UNNotificationRequest(identifier: id(batch), content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(_ batch: LeftoverBatch) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(batch)])
    }
}
