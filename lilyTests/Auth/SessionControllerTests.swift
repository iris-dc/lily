import Foundation
import Testing
@testable import lily

@MainActor
struct SessionControllerTests {
    @Test func restoreWithValidSessionSignsIn() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(TestFixtures.session)

        await harness.controller.restore()

        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func restoreWithGuestChoiceEntersGuestMode() async {
        let harness = SessionHarness()
        harness.store.stored = .guest

        await harness.controller.restore()

        #expect(harness.controller.state == .guest)
    }

    @Test func restoreWithNothingStoredSignsOut() async {
        let harness = SessionHarness()

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
    }

    /// The store is a hint: a stale `.signedIn` the auth service no longer recognises must not sign the user in.
    @Test func restoreIgnoresStaleStoredSignInWhenAuthServiceHasNoSession() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(nil)
        harness.store.stored = .signedIn(TestFixtures.session)

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
    }

    @Test func restoreFailureFallsBackToStoredChoice() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .failure(.network)
        harness.store.stored = .guest

        await harness.controller.restore()

        #expect(harness.controller.state == .guest)
        #expect(harness.errorCenter.current == nil)
    }

    @Test func restoreFailureWithNothingStoredSignsOut() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .failure(.network)

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("restore failed") })
    }

    @Test func signInSuccessUpdatesStateAndLogs() async {
        let harness = SessionHarness()

        let success = await harness.controller.signIn(with: .apple)

        #expect(success)
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.auth.signInProviders == [.apple])
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("succeeded") && $0.contains(TestFixtures.user.id) })
    }

    @Test func signInFailureReportsProviderSpecificError() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.unknown)

        let success = await harness.controller.signIn(with: .google)

        #expect(!success)
        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current?.error == .authFailed(provider: .google))
    }

    @Test func signInFailurePreservesSpecificErrors() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.invalidCredentials)

        await harness.controller.signIn(with: .email(TestFixtures.credentials))

        #expect(harness.errorCenter.current?.error == .invalidCredentials)
    }

    @Test func signUpSuccessSignsInWithSameCredentials() async {
        let harness = SessionHarness()

        let result = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(result == .signedIn)
        #expect(harness.auth.signInProviders == [.email(EmailCredentials(email: "a@b.co", password: "long-enough"))])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func signUpFailureReportsError() async {
        let harness = SessionHarness()
        harness.auth.signUpError = .invalidCredentials

        let result = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(result == .failed)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.errorCenter.current?.error == .invalidCredentials)
    }

    @Test func continueAsGuestPersistsChoice() {
        let harness = SessionHarness()

        harness.controller.continueAsGuest()

        #expect(harness.controller.state == .guest)
        #expect(harness.store.stored == .guest)
    }

    @Test func signOutClearsStoreEvenWhenRemoteFails() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.auth.signOutError = .network

        await harness.controller.signOut()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.store.stored == nil)
        #expect(harness.auth.signOutCount == 1)
    }

    /// Correlating one user's session needs the id on the way out as well as on the way in.
    @Test func signOutNamesTheUserItEnded() async {
        let harness = SessionHarness()
        await harness.controller.signIn(with: .apple)

        await harness.controller.signOut()

        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Signed out") && $0.contains(TestFixtures.user.id) })
    }

    @Test func signInSyncsTheDisplayNameOnce() async {
        let harness = SessionHarness()

        await harness.controller.signIn(with: .apple)
        await harness.controller.profileSync?.value

        #expect(harness.profile.syncedNames == [TestFixtures.user.displayName])
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Profile synced") })
    }

    @Test func signUpSyncsTheDisplayNameOnce() async {
        let harness = SessionHarness()

        await harness.controller.signUp(email: "a@b.co", password: "long-enough")
        await harness.controller.profileSync?.value

        #expect(harness.profile.syncedNames == [TestFixtures.user.displayName])
    }

    @Test func failedSignInDoesNotSyncTheProfile() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.network)

        await harness.controller.signIn(with: .apple)

        #expect(harness.controller.profileSync == nil)
        #expect(harness.profile.syncedNames.isEmpty)
    }

    /// The user did sign in; a backend that cannot take the name is a log line, never a popup.
    @Test func failedProfileSyncIsLoggedNotShown() async {
        let harness = SessionHarness()
        harness.profile.error = .network

        let success = await harness.controller.signIn(with: .apple)
        await harness.controller.profileSync?.value

        #expect(success)
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Profile sync failed") })
    }

    /// Sign-out ends the sync on purpose, so its end is a debug line, never the warning a real failure gets.
    @Test func signOutCancelsAPendingProfileSync() async {
        let harness = SessionHarness()
        harness.profile.delay = .seconds(5)

        await harness.controller.signIn(with: .apple)
        await harness.controller.signOut()
        await harness.controller.profileSync?.value

        #expect(harness.controller.profileSync?.isCancelled == true)
        #expect(harness.logger.messages(in: .auth, at: .debug).contains { $0.contains("Profile sync cancelled") })
        #expect(!harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("Profile sync failed") })
    }
}

/// Runs the controller against the real mock auth service to cover behaviour the scripted fake cannot. The mock's
/// pauses are held, so which call wins is decided by the test, not by a clock; the time limit turns a pause nobody
/// releases (a guard that stopped rejecting the second call) into a failure instead of a hang.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionControllerWithMockAuthTests {
    @MainActor private struct Harness {
        let store = InMemorySessionStore()
        let logger = SpyLogger()
        let sleep = HeldSleep()
        let controller: SessionController

        init(delay: Duration = AppConfig.Auth.mockSignInDelay) {
            controller = SessionController(authService: MockAuthService(delay: delay,
                                                                        store: store,
                                                                        sleep: { [sleep] in try await sleep.sleep(for: $0) }),
                                           sessionStore: store,
                                           profileRepository: MockProfileRepository(logger: logger),
                                           errorCenter: ErrorCenter(logger: logger),
                                           logger: logger)
        }
    }

    @Test func onlyOneSignInRunsAtATime() async {
        let harness = Harness()

        let apple = Task { await harness.controller.signIn(with: .apple) }
        await settle(until: { harness.sleep.held.count == 1 })
        let googleSucceeded = await harness.controller.signIn(with: .google)
        harness.sleep.release()
        let appleSucceeded = await apple.value

        #expect(appleSucceeded && !googleSucceeded)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.controller.state.user == MockUsers.user(for: .apple))
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Ignored authentication") })
    }

    /// A provider tap landing during the sign-up network call must be rejected, not swallow the sign-up.
    @Test func signUpHoldsTheAuthenticationSlotForItsWholeDuration() async {
        let harness = Harness()
        let credentials = TestFixtures.credentials

        let signUp = Task { await harness.controller.signUp(email: credentials.email, password: credentials.password) }
        await settle(until: { harness.sleep.held.count == 1 })
        let appleSucceeded = await harness.controller.signIn(with: .apple)
        harness.sleep.release()
        // The sign-up is followed by a sign-in with the same credentials, the mock's second pause.
        await settle(until: { harness.sleep.held.count == 1 })
        harness.sleep.release()
        let signedUp = await signUp.value

        #expect(signedUp == .signedIn)
        #expect(!appleSucceeded)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.controller.state.user == MockUsers.user(for: .email(credentials)))
    }

    /// A duplicate sign-out that finishes late must not wipe a guest choice made after the first one returned.
    @Test func lateDuplicateSignOutCannotUndoGuestChoiceMadeMeanwhile() async {
        let harness = Harness()

        let first = Task { await harness.controller.signOut() }
        await settle(until: { harness.sleep.held.count == 1 })
        await harness.controller.signOut()
        harness.sleep.release()
        await first.value
        harness.controller.continueAsGuest()

        #expect(harness.controller.state == .guest)
        #expect(harness.store.stored == .guest)
        #expect(harness.sleep.requested.count == 1, "the duplicate never reached the auth service")
    }

    @Test func logLinesNeverContainCredentials() async {
        let harness = Harness(delay: .zero)
        let credentials = TestFixtures.credentials

        await harness.controller.signUp(email: credentials.email, password: credentials.password)
        await harness.controller.resendConfirmationCode(email: credentials.email)
        await harness.controller.confirmSignUp(email: credentials.email, code: "123456", password: credentials.password)
        await harness.controller.restore()
        await harness.controller.signOut()

        let lines = harness.logger.entries.map(\.message)
        #expect(lines.count >= 6)
        for line in lines {
            #expect(!line.localizedCaseInsensitiveContains(credentials.email), "leaked email in: \(line)")
            #expect(!line.contains(credentials.password), "leaked password in: \(line)")
        }
    }
}
