import Core
import SwiftUI

/// Makes a code for a partner or caregiver and offers the share sheet.
struct InviteSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let role: InviteRole
    @State private var invite: CreatedInvite?
    @State private var childName: String?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(role == .partner ? "Invite your partner" : "Invite a caregiver")
                        .textStyle(.title)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(role == .partner
                        ? "They'll see and add to the same logs, and can do everything you can."
                        : "They'll see and add logs, but can't remove children or people.")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .padding(.top, Spacing.titleToLede)

                    if let invite {
                        code(invite)
                    } else if let problem {
                        Text(problem)
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                            .padding(.top, Spacing.ledeToSection)
                    } else {
                        ProgressView()
                            .tint(palette.graphite)
                            .padding(.top, Spacing.ledeToSection)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
            }
            .paperBackground(.oat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
        .task { await make() }
    }

    private func code(_ invite: CreatedInvite) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(invite.code.description)
                .textStyle(.display)
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .textSelection(.enabled)
                .accessibilityLabel("Code: \(invite.code.value.map(String.init).joined(separator: " "))")
            Text("Works once. Expires \(invite.expiresAt.formatted(.dateTime.month(.wide).day())).")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .padding(.top, Spacing.x2)

            ShareLink(item: invite.code.shareMessage(childName: childName, role: invite.role, expires: invite.expiresAt)) {
                Text("Share the code")
            }
            .buttonStyle(.primary)
            .padding(.top, Spacing.section)

            Text("They open Cali Care, go to Settings → Household → Join with a code, and type it in.")
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .padding(.top, Spacing.x4)
        }
        .padding(.top, Spacing.ledeToSection)
    }

    private func make() async {
        guard invite == nil, let client = Backend.client, let household = SyncSettings().householdID else {
            if invite == nil { problem = "Couldn't make a code just now. Check your connection and try again." }
            return
        }
        childName = try? await ChildStore(modelContainer: try CaliCareModelContainer.shared()).currentChild()?.name
        do {
            invite = try await HouseholdService(client: client, household: household).createInvite(role)
        } catch {
            problem = "Couldn't make a code just now. Check your connection and try again."
        }
    }
}
