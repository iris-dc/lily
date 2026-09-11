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
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("succeeded") })
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

        let success = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(success)
        #expect(harness.auth.signInProviders == [.email(EmailCredentials(email: "a@b.co", password: "long-enough"))])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func signUpFailureReportsError() async {
        let harness = SessionHarness()
        harness.auth.signUpError = .invalidCredentials

        let success = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(!success)
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

    @Test func signOutCancelsAPendingProfileSync() async {
        let harness = SessionHarness()
        harness.profile.delay = .seconds(5)

        await harness.controller.signIn(with: .apple)
        await harness.controller.signOut()

        #expect(harness.controller.profileSync?.isCancelled == true)
    }
}

/// Runs the controller against the real mock auth service to cover behaviour the scripted fake cannot.
@MainActor
struct SessionControllerWithMockAuthTests {
    @MainActor private struct Harness {
        let store = InMemorySessionStore()
        let logger = SpyLogger()
        let controller: SessionController

        init(delay: Duration) {
            controller = SessionController(authService: MockAuthService(delay: delay, store: store),
                                           sessionStore: store,
                                           profileRepository: MockProfileRepository(logger: logger),
                                           errorCenter: ErrorCenter(logger: logger),
                                           logger: logger)
        }
    }

    /// Long enough that a second call started right after the first is still overlapping it.
    private let networkDelay: Duration = .milliseconds(200)

    @Test func onlyOneSignInRunsAtATime() async {
        let harness = Harness(delay: networkDelay)

        async let apple = harness.controller.signIn(with: .apple)
        async let google = harness.controller.signIn(with: .google)
        let (appleSucceeded, googleSucceeded) = await (apple, google)

        #expect(appleSucceeded != googleSucceeded)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.controller.state.user != nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Ignored authentication") })
    }

    /// A provider tap landing during the sign-up network call must be rejected, not swallow the sign-up.
    @Test func signUpHoldsTheAuthenticationSlotForItsWholeDuration() async {
        let harness = Harness(delay: networkDelay)
        let credentials = TestFixtures.credentials

        // `signUp` runs first and claims the slot before its first suspension; the task then lands mid-flight.
        let apple = Task { await harness.controller.signIn(with: .apple) }
        let signedUp = await harness.controller.signUp(email: credentials.email, password: credentials.password)
        let appleSucceeded = await apple.value

        #expect(signedUp)
        #expect(!appleSucceeded)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.controller.state.user == MockUsers.user(for: .email(credentials)))
    }

    /// A duplicate sign-out that finishes late must not wipe a guest choice made after the first one returned.
    @Test func lateDuplicateSignOutCannotUndoGuestChoiceMadeMeanwhile() async {
        let harness = Harness(delay: networkDelay)

        let first = Task { await harness.controller.signOut() }
        let second = Task {
            try? await Task.sleep(for: networkDelay / 2)
            await harness.controller.signOut()
        }
        await first.value
        harness.controller.continueAsGuest()
        await second.value

        #expect(harness.controller.state == .guest)
        #expect(harness.store.stored == .guest)
    }

    @Test func logLinesNeverContainCredentials() async {
        let harness = Harness(delay: .zero)
        let credentials = TestFixtures.credentials

        await harness.controller.signUp(email: credentials.email, password: credentials.password)
        await harness.controller.restore()
        await harness.controller.signOut()

        let lines = harness.logger.entries.map(\.message)
        #expect(lines.count >= 4)
        for line in lines {
            #expect(!line.localizedCaseInsensitiveContains(credentials.email), "leaked email in: \(line)")
            #expect(!line.contains(credentials.password), "leaked password in: \(line)")
        }
    }
}
