import Core
import Foundation
import Observation
import Supabase

/// The optional account for the whole app. Signing in only adds sharing;
/// signing out keeps every log on this phone.
@MainActor
@Observable
final class AccountController {
    private(set) var state: AccountState = .signedOut
    private(set) var isWorking = false
    var problem: String?

    /// False when this build has no Supabase project configured.
    var isAvailable: Bool { client != nil }

    private let client: SupabaseClient?
    private var signingOut = false
    private var watching: Task<Void, Never>?

    init(client: SupabaseClient? = Backend.client) {
        self.client = client
    }

    /// Follows the stored session: sign-ins, renewals, and sign-outs.
    func start() {
        loadStoredSession()
        guard let client, watching == nil else { return }
        watching = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                self?.apply(event: event, session: session)
            }
        }
    }

    /// Reads the saved session right away, e.g. when iOS wakes the app in the
    /// background before any screen has loaded.
    func loadStoredSession() {
        guard let client, case .signedOut = state, let session = client.auth.currentSession else { return }
        apply(event: .initialSession, session: session)
    }

    /// Hands Apple's identity token to Supabase.
    func signIn(idToken: String, nonce: String) async {
        guard let client else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
            apply(event: .signedIn, session: session)
            problem = nil
        } catch {
            problem = "Couldn't sign in just now. Your logs are safe on this phone. Try again in a moment."
        }
    }

    /// Saves what others see, on the account and on this phone.
    func setDisplayName(_ raw: String) async -> Bool {
        guard let client, let name = DisplayName.clean(raw) else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let user = try await client.auth.update(user: UserAttributes(data: ["display_name": .string(name)]))
            AccountSettings().displayName = name
            state = .signedIn(AccountInfo(userID: user.id, displayName: name))
            problem = nil
            return true
        } catch {
            problem = "Couldn't save your name. Check your connection and try again."
            return false
        }
    }

    /// Ends the session. Children and logs stay on this phone.
    func signOut() async {
        guard let client else { return }
        signingOut = true
        defer { signingOut = false }
        try? await client.auth.signOut(scope: .local)
        AccountSettings().displayName = nil
        state = .signedOut
    }

    /// Deletes the account on the server (see supabase/functions/delete-account),
    /// then signs out here. With `erasePhone`, children and logs leave this
    /// phone too; otherwise they stay, like before signing in. Apple's sheet
    /// asks first, so the server can tell Apple to forget the app.
    func deleteAccount(erasePhone: Bool) async -> Bool {
        guard let client else { return false }
        isWorking = true
        defer { isWorking = false }
        let appleCode: String?
        switch await AppleReauthorization.code() {
        case .code(let code): appleCode = code
        case .canceled: return false
        case .unavailable: appleCode = nil
        }
        struct Deleted: Decodable { let deleted: Bool }
        struct Body: Encodable { let apple_authorization_code: String? }
        do {
            let result: Deleted = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(method: .post, body: Body(apple_authorization_code: appleCode))
            )
            guard result.deleted else { throw CancellationError() }
        } catch {
            problem = "Couldn't delete your account just now. Nothing was changed. Check your connection and try again."
            return false
        }
        signingOut = true
        try? await client.auth.signOut(scope: .local)
        signingOut = false
        AccountSettings().displayName = nil
        state = .signedOut
        problem = nil
        if erasePhone, let container = try? CaliCareModelContainer.shared() {
            try? LocalData.eraseAll(container: container)
            await LogChanges.didChange()
        }
        return true
    }

    private func apply(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .signedOut where !signingOut:
            // The session couldn't be renewed. Keep who they were, so Settings
            // can offer to sign in again; nothing on the phone changes.
            if let info = state.info { state = .expired(info) }
        case .signedOut:
            state = .signedOut
        default:
            let snapshot = session.map {
                SessionSnapshot(userID: $0.user.id, expiresAt: Date(timeIntervalSince1970: $0.expiresAt))
            }
            let name = session.flatMap { Self.displayName(in: $0.user) } ?? AccountSettings().displayName
            state = AccountState.resolve(session: snapshot, displayName: name)
            if let name = state.info?.displayName { AccountSettings().displayName = name }
        }
    }

    private static func displayName(in user: User) -> String? {
        if case .string(let name) = user.userMetadata["display_name"] { return DisplayName.clean(name) }
        return nil
    }
}
