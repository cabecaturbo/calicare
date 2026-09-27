import Core
import SwiftUI

/// Settings → Account. Hidden when this build has no Supabase project.
struct AccountSection: View {
    @Environment(AccountController.self) private var account
    @Environment(SyncController.self) private var sync
    @Environment(\.palette) private var palette
    @State private var showingSheet = false
    @State private var confirmingSignOut = false

    var body: some View {
        if account.isAvailable {
            LedgerSection("Account", footnote: footnote) {
                switch account.state {
                case .signedOut:
                    row("Share logs with your partner") { showingSheet = true }
                case .expired:
                    row("Sign in again to keep sharing") { showingSheet = true }
                case .signedIn(let info):
                    Button { showingSheet = true } label: {
                        LedgerRow {
                            Text("Shown as")
                                .textStyle(.control)
                                .foregroundStyle(palette.ink)
                        } trailing: {
                            Text(info.displayName ?? "Add a name")
                                .textStyle(.meta)
                                .foregroundStyle(info.displayName == nil ? palette.indigo : palette.graphite)
                        }
                    }
                    .buttonStyle(.ledger)
                    .accessibilityHint("Change the name others see")
                    NavigationLink {
                        HouseholdView()
                    } label: {
                        NavigationRow(title: "Household")
                    }
                    .buttonStyle(.ledger)
                    row("Sign out") { confirmingSignOut = true }
                }
            }
            .sheet(isPresented: $showingSheet) {
                AccountSheet()
                    .environment(account)
                    .nightAwarePalette()
            }
            .confirmationDialog(
                "Sign out? Your logs stay on this phone.",
                isPresented: $confirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out") { Task { await account.signOut() } }
                Button("Stay signed in", role: .cancel) {}
            }
        }
    }

    private var footnote: String {
        switch account.state {
        case .signedOut: "Optional. Everything works without an account."
        case .expired: "Your logs are all still on this phone."
        case .signedIn: "\(lastSynced) Signing out keeps everything on this phone."
        }
    }

    /// "Last synced 2:14 PM." or "Last synced Sep 25, 2:14 PM."
    private var lastSynced: String {
        guard let date = sync.lastSyncedAt else { return "Not synced yet." }
        let when = Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "Last synced \(when)."
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NavigationRow(title: title)
        }
        .buttonStyle(.ledger)
    }
}
