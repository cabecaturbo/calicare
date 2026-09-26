import Core
import SwiftUI

/// Settings. For now just the recent-logs check; more arrives with notifications (Prompt 5).
struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Recent logs") {
                        RecentLogsView()
                    }
                    .font(Typography.body)
                    .frame(minHeight: TouchTarget.minimum)
                } header: {
                    Text("Behind the scenes")
                } footer: {
                    Text("See what widgets, Siri, and Control Center saved.")
                }
                .listRowBackground(palette.card)
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
    }
}
