import Foundation
import Testing
@testable import lily

/// A pool session found on restore: Amplify keeps `isSignedIn` true after the refresh token expired, so a token
/// request decides, and the compensating pool sign-out logs its own failure. A sign-out is marked in the store until
/// the pool confirmed it, so a launch that finds the marker or a guest choice next to a pool session ends that session.
extension CognitoAuthServiceTests {
    // MARK: Restore with a pool session

    @Test func anExpiredRefreshTokenOnRestoreClearsTheCachedUser() async throws {
        let harness = Harness()
        harness.client.signedIn = true
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.client.tokenResult = .failure(.sessionExpired)

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == nil)
        #expect(harness.client.signOutCount == 1)
        #expect(!harness.client.signedIn)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("refresh token expired") })
    }

    /// A token request that fails for any other reason (offline) keeps the user: the backend's 401 decides then.
    @Test func restoreOfflineKeepsTheCachedUser() async throws {
        let harness = Harness()
        harness.client.signedIn = true
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.client.tokenResult = .failure(.network)

        #expect(try await harness.service.restoreSession() == TestFixtures.session)

        #expect(harness.store.stored == .signedIn(TestFixtures.session))
        #expect(harness.client.signOutCount == 0)
    }

    @Test func anExpiredRefreshTokenWithoutACacheNeverLoadsTheUser() async throws {
        let harness = Harness()
        harness.client.signedIn = true
        harness.client.tokenResult = .failure(.sessionExpired)

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == nil)
        #expect(harness.client.signOutCount == 1)
    }

    /// The load's error is the one the caller sees; the sign-out's own failure gets the one line that explains a later
    /// launch's silent sign-in.
    @Test func aFailedUserLoadWhosePoolSignOutAlsoFailsIsLogged() async {
        let harness = Harness()
        harness.client.signedIn = true
        harness.client.emailResult = .failure(.network)
        harness.client.signOutError = .other("keychain")

        await #expect(throws: AppError.network) { try await harness.service.restoreSession() }

        #expect(harness.client.signOutCount == 1)
        let warnings = harness.logger.messages(in: .auth, at: .warning)
        #expect(warnings.count == 2)
        #expect(warnings.contains { $0.contains("signing out") })
        #expect(warnings.contains { $0.contains("failed too") })
        let email = TestFixtures.credentials.email
        #expect(!harness.logger.entries.contains { $0.message.contains(email) }, "no email in the log")
    }

    // MARK: Pending sign-out

    @Test func signOutMarksThePendingSignOutBeforeAskingThePool() async throws {
        let harness = Harness()
        harness.store.stored = .signedIn(TestFixtures.session)
        var seen: StoredSession?
        harness.client.onSignOut = { seen = harness.store.stored }

        try await harness.service.signOut()

        #expect(seen == .signingOut)
        #expect(harness.store.stored == nil)
        #expect(harness.client.signOutCount == 1)
    }

    /// A choice made on the landing while Amplify is still being asked is never undone by the sign-out's return.
    @Test func aGuestChoiceMadeWhileThePoolSignsOutIsKept() async throws {
        let harness = Harness()
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.client.onSignOut = { harness.store.save(.guest) }

        try await harness.service.signOut()

        #expect(harness.store.stored == .guest)
        #expect(harness.client.signOutCount == 1)
    }

    @Test func aSignOutInterruptedBeforeTheKeychainDeleteFinishesOnTheNextLaunch() async throws {
        let harness = Harness()
        harness.store.stored = .signingOut
        harness.client.signedIn = true

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.client.signOutCount == 1)
        #expect(!harness.client.signedIn)
        #expect(harness.store.stored == nil)
        #expect(harness.logger.messages(in: .auth, at: .info).contains { $0.contains("interrupted") })
    }

    /// The retry's failure is the compensating sign-out's warning; the marker waits for the launch after.
    @Test func aRetriedPoolSignOutThatFailsAgainKeepsTheMarkerForTheNextLaunch() async throws {
        let harness = Harness()
        harness.store.stored = .signingOut
        harness.client.signedIn = true
        harness.client.signOutError = .other("keychain")

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == .signingOut)
        #expect(harness.client.signedIn)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("failed too") })
    }

    /// Killed after Amplify deleted the keychain but before the marker went: nothing left to sign out of.
    @Test func aMarkerLeftAfterACompletedPoolSignOutIsCleared() async throws {
        let harness = Harness()
        harness.store.stored = .signingOut

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == nil)
        #expect(harness.client.signOutCount == 0)
    }

    @Test func aGuestChoiceNextToALeftoverPoolSessionEndsItAndStaysGuest() async throws {
        let harness = Harness()
        harness.store.stored = .guest
        harness.client.signedIn = true

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == .guest)
        #expect(harness.client.signOutCount == 1)
        #expect(!harness.client.signedIn)
    }
}
