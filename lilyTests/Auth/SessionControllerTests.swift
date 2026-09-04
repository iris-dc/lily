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

    @Test func restoreFailureFallsBackToStoredChoice() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .failure(.network)
        harness.store.stored = .guest

        await harness.controller.restore()

        #expect(harness.controller.state == .guest)
        #expect(harness.errorCenter.current == nil)
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
        #expect(harness.auth.signInProviders == [.email])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func signUpFailureReportsError() async {
        let harness = SessionHarness()
        harness.auth.signUpError = .invalidCredentials

        let success = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(!success)
        #expect(harness.auth.signInProviders.isEmpty)
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
}

/// Runs the controller against the real mock auth service to cover behaviour the scripted fake cannot.
@MainActor
struct SessionControllerWithMockAuthTests {
    private func makeController(delay: Duration) -> (SessionController, SpyLogger) {
        let store = InMemorySessionStore()
        let logger = SpyLogger()
        let controller = SessionController(authService: MockAuthService(delay: delay, store: store),
                                           sessionStore: store,
                                           errorCenter: ErrorCenter(logger: logger),
                                           logger: logger)
        return (controller, logger)
    }

    @Test func onlyOneSignInRunsAtATime() async {
        let (controller, _) = makeController(delay: .milliseconds(200))

        async let apple = controller.signIn(with: .apple)
        async let google = controller.signIn(with: .google)
        let (appleSucceeded, googleSucceeded) = await (apple, google)

        #expect(appleSucceeded != googleSucceeded)
        #expect(controller.authenticatingProvider == nil)
        #expect(controller.state.user != nil)
    }

    @Test func logLinesNeverContainCredentials() async {
        let (controller, logger) = makeController(delay: .zero)
        let credentials = TestFixtures.credentials

        await controller.signUp(email: credentials.email, password: credentials.password)
        await controller.restore()
        await controller.signOut()

        let lines = logger.entries.map(\.message)
        #expect(lines.count >= 4)
        for line in lines {
            #expect(!line.localizedCaseInsensitiveContains(credentials.email), "leaked email in: \(line)")
            #expect(!line.contains(credentials.password), "leaked password in: \(line)")
        }
    }
}
