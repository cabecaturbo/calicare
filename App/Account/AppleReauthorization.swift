import AuthenticationServices
import UIKit

/// Asks Apple for a fresh authorization code, so the server can revoke the
/// app's Sign in with Apple token when the account is deleted
/// (supabase/functions/delete-account/apple.ts). Shows Apple's own sheet.
@MainActor
final class AppleReauthorization: NSObject {
    enum Outcome {
        case code(String)
        /// The person closed Apple's sheet.
        case canceled
        /// Apple couldn't give a code; deletion goes ahead without it.
        case unavailable
    }

    private var continuation: CheckedContinuation<Outcome, Never>?
    private var controller: ASAuthorizationController?

    static func code() async -> Outcome {
        await AppleReauthorization().run()
    }

    private func run() async -> Outcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ outcome: Outcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
        controller = nil
    }
}

extension AppleReauthorization: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)?
            .authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }
        MainActor.assumeIsolated {
            finish(code.map(Outcome.code) ?? .unavailable)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let canceled = (error as? ASAuthorizationError)?.code == .canceled
        MainActor.assumeIsolated {
            finish(canceled ? .canceled : .unavailable)
        }
    }
}

extension AppleReauthorization: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
