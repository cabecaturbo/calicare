import Core
import Foundation
import Testing

struct AccountStateTests {
    let user = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func noSessionIsSignedOut() {
        #expect(AccountState.resolve(session: nil, displayName: "Mom", now: now) == .signedOut)
    }

    @Test func liveSessionIsSignedIn() {
        let session = SessionSnapshot(userID: user, expiresAt: now.addingTimeInterval(3600))
        let state = AccountState.resolve(session: session, displayName: "Mom", now: now)
        #expect(state == .signedIn(AccountInfo(userID: user, displayName: "Mom")))
        #expect(!state.needsDisplayName)
    }

    /// Offline or between renewals: an old access token alone never signs anyone out.
    @Test func expiredTokenThatMayStillRenewIsSignedIn() {
        let session = SessionSnapshot(userID: user, expiresAt: now.addingTimeInterval(-60))
        #expect(AccountState.resolve(session: session, displayName: nil, now: now)
            == .signedIn(AccountInfo(userID: user, displayName: nil)))
    }

    @Test func expiredAndCouldNotRenewIsExpired() {
        let session = SessionSnapshot(userID: user, expiresAt: now.addingTimeInterval(-60), refreshFailed: true)
        let state = AccountState.resolve(session: session, displayName: "Dad", now: now)
        #expect(state == .expired(AccountInfo(userID: user, displayName: "Dad")))
        #expect(state.info?.displayName == "Dad")
        #expect(!state.needsDisplayName)
    }

    @Test func aFailedRenewalBeforeExpiryStaysSignedIn() {
        let session = SessionSnapshot(userID: user, expiresAt: now.addingTimeInterval(600), refreshFailed: true)
        #expect(AccountState.resolve(session: session, displayName: "Dad", now: now).info != nil)
        #expect(AccountState.resolve(session: session, displayName: "Dad", now: now)
            == .signedIn(AccountInfo(userID: user, displayName: "Dad")))
    }

    @Test func signedInWithoutANameAsksForOne() {
        let session = SessionSnapshot(userID: user, expiresAt: now.addingTimeInterval(3600))
        #expect(AccountState.resolve(session: session, displayName: "   ", now: now).needsDisplayName)
        #expect(!AccountState.signedOut.needsDisplayName)
    }

    @Test func displayNamesAreTrimmedAndCapped() {
        #expect(DisplayName.clean("  Grandma \n") == "Grandma")
        #expect(DisplayName.clean("   ") == nil)
        #expect(DisplayName.clean(String(repeating: "a", count: 60))?.count == DisplayName.maxLength)
    }
}
