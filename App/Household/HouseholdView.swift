import Core
import SwiftUI

/// Settings → Household: who's in it, inviting a partner or caregiver, and
/// joining someone else's household with a code.
struct HouseholdView: View {
    @Environment(AccountController.self) private var account
    @Environment(SyncController.self) private var sync
    @Environment(\.palette) private var palette
    @State private var members: [HouseholdMember] = []
    @State private var loaded = false
    @State private var problem: String?
    @State private var inviting: InviteRole?
    @State private var joining = false
    @State private var removing: HouseholdMember?

    private var me: UUID? { account.state.info?.userID }
    private var amOwner: Bool { members.first { $0.userID == me }?.isOwner ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                LedgerSection("Members", footnote: problem ?? membersFootnote) {
                    ForEach(members) { member in
                        memberRow(member)
                    }
                    if !loaded {
                        LedgerRow {
                            ProgressView().tint(palette.graphite)
                        }
                    }
                }

                if amOwner {
                    LedgerSection("Invite", footnote: "A code works once and lasts a week. Partners can do everything; caregivers can log but can't remove children or people.") {
                        inviteRow("Invite your partner", .partner)
                        inviteRow("Invite a caregiver", .caregiver)
                    }
                }

                LedgerSection("Join", footnote: "Got a code from someone? Enter it to share their household.") {
                    Button { joining = true } label: { NavigationRow(title: "Join with a code") }
                        .buttonStyle(.ledger)
                }
            }
            .padding(.vertical, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle("Household")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $inviting) { role in
            InviteSheet(role: role)
                .environment(account)
                .environment(sync)
                .nightAwarePalette()
        }
        .sheet(isPresented: $joining, onDismiss: { Task { await load() } }) {
            JoinSheet()
                .environment(account)
                .environment(sync)
                .nightAwarePalette()
        }
        .confirmationDialog(removeTitle, isPresented: removingShown, titleVisibility: .visible, presenting: removing) { member in
            Button(member.userID == me ? "Leave and sign out" : "Remove \(member.displayName)") {
                Task { await remove(member) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text(member.userID == me
                ? "You'll be signed out on this phone. Everything already here stays."
                : "\(member.displayName) will stop seeing and adding logs. Logs they added stay.")
        }
    }

    private var membersFootnote: String? {
        loaded && members.count == 1 ? "Just you so far." : nil
    }

    private func memberRow(_ member: HouseholdMember) -> some View {
        let isMe = member.userID == me
        let canRemove = isMe || amOwner
        let role = member.isOwner ? "Owner" : "Caregiver"
        return Button {
            removing = member
        } label: {
            LedgerRow {
                Text(isMe ? "\(member.displayName) (you)" : member.displayName)
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            } trailing: {
                Text(role)
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
        }
        .buttonStyle(.ledger)
        .disabled(!canRemove)
        .accessibilityHint(canRemove ? (isMe ? "Leave the household" : "Remove from the household") : "")
    }

    private func inviteRow(_ title: String, _ role: InviteRole) -> some View {
        Button { inviting = role } label: { NavigationRow(title: title) }
            .buttonStyle(.ledger)
    }

    private var removeTitle: String {
        guard let removing else { return "" }
        return removing.userID == me ? "Leave this household?" : "Remove \(removing.displayName)?"
    }

    private var removingShown: Binding<Bool> {
        Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
    }

    private func service() async -> HouseholdService? {
        if SyncSettings().householdID == nil { await sync.syncNow() }
        guard let client = Backend.client, let household = SyncSettings().householdID else { return nil }
        return HouseholdService(client: client, household: household)
    }

    private func load() async {
        guard let service = await service() else {
            problem = "Couldn't load your household. Check your connection and try again."
            loaded = true
            return
        }
        do {
            members = try await service.members()
            problem = nil
        } catch {
            problem = "Couldn't load your household. Check your connection and try again."
        }
        loaded = true
    }

    private func remove(_ member: HouseholdMember) async {
        let isMe = member.userID == me
        if isMe, member.isOwner, members.filter(\.isOwner).count == 1, members.count > 1 {
            problem = "You're the only owner. Invite a partner as an owner before leaving."
            return
        }
        guard let service = await service() else { return }
        do {
            try await service.remove(member)
            if isMe {
                await account.signOut()
            } else {
                await load()
            }
        } catch {
            problem = "Couldn't make that change just now. Try again in a moment."
        }
    }
}
