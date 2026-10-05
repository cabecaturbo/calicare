import Core
import SwiftUI

/// Settings → Family: signing in to share, and the household (members, invites).
/// Hidden when this build has no Supabase project.
struct FamilySection: View {
    @Environment(AccountController.self) private var account
    @State private var showingSheet = false

    var body: some View {
        if account.isAvailable {
            SettingsSection("Family", footnote: footnote) {
                switch account.state {
                case .signedOut:
                    Button { showingSheet = true } label: { SettingsLabel("Share logs with your partner") }
                case .expired:
                    Button { showingSheet = true } label: { SettingsLabel("Sign in again to keep sharing") }
                case .signedIn:
                    NavigationLink {
                        HouseholdView()
                    } label: {
                        SettingsLabel("Household")
                    }
                }
            }
            .sheet(isPresented: $showingSheet) {
                AccountSheet()
                    .environment(account)
                    .nightAwarePalette()
            }
        }
    }

    private var footnote: String {
        switch account.state {
        case .signedOut: "Optional. Everything works without an account."
        case .expired: "Your logs are all still on this phone."
        case .signedIn: "Members and invites."
        }
    }
}

/// Settings → Account: the name others see, signing out, deleting the account.
/// Only while signed in.
struct AccountSettingsSection: View {
    @Environment(AccountController.self) private var account
    @Environment(SyncController.self) private var sync
    @Environment(\.palette) private var palette
    @State private var showingSheet = false
    @State private var confirmingSignOut = false
    @State private var deleting = false

    var body: some View {
        if account.isAvailable, case .signedIn(let info) = account.state {
            SettingsSection("Account", footnote: "\(lastSynced) Signing out keeps everything on this phone.") {
                Button { showingSheet = true } label: {
                    LabeledContent {
                        Text(info.displayName ?? "Add a name")
                            .textStyle(.meta)
                            .foregroundStyle(info.displayName == nil ? palette.accent : palette.graphite)
                    } label: {
                        SettingsLabel("Shown as")
                    }
                }
                .accessibilityHint("Change the name others see")
                Button { confirmingSignOut = true } label: { SettingsLabel("Sign out") }
                Button { deleting = true } label: { SettingsLabel("Delete account") }
            }
            .sheet(isPresented: $showingSheet) {
                AccountSheet()
                    .environment(account)
                    .nightAwarePalette()
            }
            .sheet(isPresented: $deleting) {
                DeleteAccountSheet()
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

    /// "Last synced 2:14 PM." or "Last synced Sep 25, 2:14 PM."
    private var lastSynced: String {
        guard let date = sync.lastSyncedAt else { return "Not synced yet." }
        let when = Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "Last synced \(when)."
    }
}
