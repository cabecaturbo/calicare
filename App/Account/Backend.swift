import Foundation
import Supabase

/// The Supabase client, when this build has a project configured. Without
/// Config/Supabase.local.xcconfig there's no client and accounts stay hidden;
/// the app works exactly as before.
enum Backend {
    static let client: SupabaseClient? = makeClient()

    private static func makeClient() -> SupabaseClient? {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let host = (info["SupabaseHost"] as? String).flatMap(nonEmpty),
              let key = (info["SupabasePublishableKey"] as? String).flatMap(nonEmpty),
              let url = URL(string: "https://\(host)")
        else { return nil }

        // The session lives in a keychain group the widgets can read later.
        let prefix = (info["AppIdentifierPrefix"] as? String) ?? ""
        let storage = KeychainLocalStorage(accessGroup: "\(prefix)com.cursorkittens.calicare.shared")
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(storage: storage, emitLocalSessionAsInitialSession: true))
        )
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
