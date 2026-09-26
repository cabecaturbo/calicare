import Core
import SwiftUI

/// Settings: reminders, plus a behind-the-scenes check of what was logged.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderController.self) private var reminders

    var body: some View {
        NavigationStack {
            List {
                ReminderSettingsSection()

                Section {
                    NavigationLink("Recent logs") {
                        RecentLogsView()
                    }
                    .font(Typography.body)
                    .frame(minHeight: TouchTarget.minimum)
                } header: {
                    Text("Behind the scenes")
                } footer: {
                    Text("See what widgets, Siri, Control Center, and notifications saved.")
                }
                .listRowBackground(palette.card)

                #if DEBUG
                TryNotificationSection()
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
        .task { await reminders.reload() }
        .sheet(isPresented: toggleOffer) {
            ReminderOfferSheet(
                onTurnOn: { Task { await reminders.acceptOffer() } },
                onNotNow: { reminders.declineOffer() }
            )
        }
    }

    /// Shown when a reminder is switched on before notifications were ever allowed.
    private var toggleOffer: Binding<Bool> {
        Binding(
            get: {
                if case .toggle = reminders.offer { return true }
                return false
            },
            set: { isShowing in
                if !isShowing, case .toggle = reminders.offer { reminders.declineOffer() }
            }
        )
    }
}
