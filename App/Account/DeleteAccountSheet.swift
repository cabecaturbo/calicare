import Core
import SwiftUI

/// Says exactly what deleting the account removes, and lets the person
/// choose whether this phone's data goes too. Calm; no red.
struct DeleteAccountSheet: View {
    @Environment(AccountController.self) private var account
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OnboardingFlag.key) private var hasOnboarded = true
    @State private var erasePhone = false
    @State private var confirming = false
    @State private var lastOwner: Bool?
    @State private var others: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                        Text("Delete your account?")
                            .textStyle(.title)
                            .foregroundStyle(palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("This can't be undone.")
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                    }
                    .padding(.horizontal, Spacing.margin)

                    LedgerSection("On the server") {
                        item("Your account and the name others see\(account.state.info?.displayName.map { " (\($0))" } ?? "").")
                        item(householdLine)
                    }

                    LedgerSection("On this phone", footnote: erasePhone
                        ? "Children and logs will be erased from this phone too."
                        : "Children and logs stay on this phone, like before you signed in.") {
                        LedgerRow {
                            Toggle(isOn: $erasePhone) {
                                Text("Also delete data on this phone")
                                    .textStyle(.control)
                                    .foregroundStyle(palette.ink)
                            }
                            .tint(palette.indigo)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.x3) {
                        Button("Delete account") { confirming = true }
                            .buttonStyle(.secondary)
                            .disabled(account.isWorking || lastOwner == nil)
                        if let problem = account.problem {
                            Text(problem)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                        }
                    }
                    .padding(.horizontal, Spacing.margin)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Spacing.x4)
            }
            .paperBackground(.oat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep my account") { dismiss() }
                }
            }
            .confirmationDialog("Delete your account?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Delete account") { Task { await delete() } }
                Button("Keep my account", role: .cancel) {}
            } message: {
                Text(erasePhone ? "Your account, and the data on this phone." : "Your account. Data on this phone stays.")
            }
        }
        .tint(palette.indigo)
        .task { await load() }
    }

    private var householdLine: String {
        guard let lastOwner else { return "Checking your household…" }
        if !lastOwner {
            return "You'll leave the household. It carries on for the others, with all its logs."
        }
        if others.isEmpty {
            return "Your household's children and logs stored online."
        }
        return "The shared household and all its children and logs. \(Self.list(others)) will lose access."
    }

    private func item(_ text: String) -> some View {
        LedgerRow {
            Text(text)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
        }
    }

    private func load() async {
        guard let client = Backend.client, let household = SyncSettings().householdID else {
            lastOwner = false
            return
        }
        let service = HouseholdService(client: client, household: household)
        lastOwner = (try? await service.amLastOwner()) ?? false
        let me = account.state.info?.userID
        others = ((try? await service.members()) ?? []).filter { $0.userID != me }.map(\.displayName)
    }

    private func delete() async {
        guard await account.deleteAccount(erasePhone: erasePhone) else { return }
        dismiss()
        // With the phone erased too, start over at the welcome screen.
        if erasePhone { hasOnboarded = false }
    }

    /// "Dad", "Dad and Grandma", "Dad, Grandma, and Sam".
    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: names.dropLast().joined(separator: ", ") + ", and " + names.last!
        }
    }
}
