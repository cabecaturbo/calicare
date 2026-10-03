import CryptoKit
import Foundation
import Security

/// Sign in with Apple ties the identity token to a one-time nonce: Apple gets
/// its SHA-256 hash, and Supabase gets the raw value to check against it.
struct AppleSignInNonce {
    let raw: String
    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        raw = status == errSecSuccess
            ? bytes.map { String(format: "%02x", $0) }.joined()
            : UUID().uuidString + UUID().uuidString
    }
}
