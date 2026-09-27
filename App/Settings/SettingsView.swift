import Core
import SwiftUI

/// Settings: reminders, quick logging setup, and (tucked at the bottom) a check of what was logged.
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderController.self) private var reminders

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    ReminderSettingsSection()

                    LedgerSection("Quick logging", footnote: "Log without opening the app.") {
                        NavigationLink {
                            QuickLoggingGuideView()
                        } label: {
                            NavigationRow(title: "Widgets, Siri, and Action Button")
                        }
                        .buttonStyle(.ledger)
                    }

                    LedgerSection(
                        "Behind the scenes",
                        footnote: "See what widgets, Siri, Control Center, and notifications saved."
                    ) {
                        NavigationLink {
                            RecentLogsView()
                        } label: {
                            NavigationRow(title: "Recent logs")
                        }
                        .buttonStyle(.ledger)
                    }

                    #if DEBUG
                    TryNotificationSection()
                    #endif
                }
                .padding(.vertical, Spacing.x4)
            }
            .paperBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
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

/// A ledger row that opens another page.
struct NavigationRow: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        LedgerRow {
            Text(title)
                .textStyle(.control)
                .foregroundStyle(palette.ink)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.regular))
                .foregroundStyle(palette.graphite)
                .accessibilityHidden(true)
        }
    }
}
