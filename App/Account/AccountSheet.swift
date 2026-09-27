import AuthenticationServices
import Core
import SwiftUI

/// "Share logs with your partner": Sign in with Apple, then the name others
/// see. Optional; closing it changes nothing.
struct AccountSheet: View {
    @Environment(AccountController.self) private var account
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var nonce = AppleSignInNonce()
    @State private var name = AccountSettings().displayName ?? ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if needsSignIn {
                        signIn
                    } else {
                        nameStep
                    }
                    if let problem = account.problem {
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
                    Button("Not now") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
    }

    /// Signed out, or signed in before but the session ran out.
    private var needsSignIn: Bool {
        if case .signedIn = account.state { return false }
        return true
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Share logs with your partner")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in so a partner or caregiver can see and add to the same logs. Everything keeps working on this phone without an account.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .padding(.top, Spacing.titleToLede)
            Text("CaliCare only gets a private relay email from Apple, and never your password.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
                .padding(.top, Spacing.x3)

            SignInWithAppleButton(.signIn) { request in
                nonce = AppleSignInNonce()
                request.requestedScopes = [.fullName]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                guard case .success(let authorization) = result,
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8)
                else {
                    if case .failure(let error) = result,
                       (error as? ASAuthorizationError)?.code != .canceled {
                        account.problem = "Sign in with Apple didn't finish. Try again in a moment."
                    }
                    return
                }
                if name.isEmpty, let given = credential.fullName?.givenName { name = given }
                Task { await account.signIn(idToken: token, nonce: nonce.raw) }
            }
            .signInWithAppleButtonStyle(palette.isNight ? .white : .black)
            .frame(height: Size.button(isNight: palette.isNight))
            .clipShape(RoundedRectangle(cornerRadius: Corner.control))
            .padding(.top, Spacing.ledeToSection)
            .disabled(account.isWorking)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.margin)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                Text("What should others see?")
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("It shows next to what you log, like \u{201C}by Dad.\u{201D}")
                    .textStyle(.body)
                    .foregroundStyle(palette.graphite)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.ledeToSection)

            Hairline()
            LedgerRow {
                TextField("Mom, Dad, Grandma", text: $name)
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit(save)
                    .accessibilityLabel("Name others see")
            }

            Button("Save", action: save)
                .buttonStyle(.primary)
                .disabled(DisplayName.clean(name) == nil || account.isWorking)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.section)
        }
        .onAppear { nameFocused = true }
    }

    private func save() {
        Task {
            if await account.setDisplayName(name) { dismiss() }
        }
    }
}
