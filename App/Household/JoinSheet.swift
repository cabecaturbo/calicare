import Core
import SwiftUI

/// Enter a code to join someone's household. If this phone already has logs,
/// asks before adding them to it.
struct JoinSheet: View {
    @Environment(AccountController.self) private var account
    @Environment(SyncController.self) private var sync
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var working = false
    @State private var problem: String?
    @State private var confirmCount: (children: Int, logs: Int)?
    @State private var joined = false
    @FocusState private var focused: Bool

    private var code: InviteCode? { InviteCode(typed) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                        Text(joined ? "You're in" : "Join with a code")
                            .textStyle(.title)
                            .foregroundStyle(palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(joined
                            ? "Logs from everyone in the household will show up here in a moment."
                            : "Type the 6-character code you were sent.")
                            .textStyle(.body)
                            .foregroundStyle(palette.graphite)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.bottom, Spacing.ledeToSection)

                    if !joined {
                        Hairline()
                        LedgerRow {
                            TextField("ABC 234", text: $typed)
                                .textStyle(.lede)
                                .foregroundStyle(palette.ink)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.join)
                                .focused($focused)
                                .onSubmit(start)
                                .accessibilityLabel("Invite code")
                        }
                        Button("Join", action: start)
                            .buttonStyle(.primary)
                            .disabled(code == nil || working)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.section)
                    } else {
                        Button("Done") { dismiss() }
                            .buttonStyle(.primary)
                            .padding(.horizontal, Spacing.margin)
                    }

                    if let problem {
                        Text(problem)
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x4)
                    }
                }
                .padding(.top, Spacing.x4)
            }
            .paperBackground(.oat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !joined { Button("Cancel") { dismiss() } }
                }
            }
            .confirmationDialog(
                "Add what's on this phone?",
                isPresented: Binding(get: { confirmCount != nil }, set: { if !$0 { confirmCount = nil } }),
                titleVisibility: .visible
            ) {
                Button("Join and add them") { Task { await join() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(mergeMessage)
            }
        }
        .tint(palette.indigo)
        .onAppear { focused = true }
    }

    private var mergeMessage: String {
        let count = confirmCount ?? (children: 0, logs: 0)
        let logs = count.logs == 1 ? "1 log" : "\(count.logs) logs"
        let children = count.children == 1 ? "1 child" : "\(count.children) children"
        return "This phone has \(children) and \(logs). Joining adds them to the shared household, where everyone in it can see them."
    }

    /// Asks first if this phone already has something to merge.
    private func start() {
        guard code != nil, !working else { return }
        Task {
            let engine = try? makeEngine()
            let count = (try? await engine?.localRecordCount()) ?? (children: 0, logs: 0)
            if count.children + count.logs > 0 {
                confirmCount = count
            } else {
                await join()
            }
        }
    }

    private func join() async {
        guard let code, let client = Backend.client, let info = account.state.info,
              let name = info.displayName ?? AccountSettings().displayName
        else {
            problem = "Sign in and choose a name first, in Settings → Account."
            return
        }
        working = true
        defer { working = false }
        do {
            let household = try await HouseholdJoin.accept(code, displayName: name, client: client)
            try await makeEngine().join(household: household, userID: info.userID, displayName: name)
            problem = nil
            joined = true
            await sync.syncNow()
        } catch let problem as JoinProblem {
            self.problem = problem.message
        } catch {
            self.problem = JoinProblem.other.message
        }
    }

    private func makeEngine() throws -> SyncEngine {
        guard let client = Backend.client else { throw JoinProblem.other }
        return SyncEngine(modelContainer: try CaliCareModelContainer.shared(), remote: SupabaseSyncRemote(client: client))
    }
}
