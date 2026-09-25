import Foundation
import Testing
@testable import lily

@MainActor
struct CognitoAuthServiceTests {
    @MainActor private struct Harness {
        let client = FakeCognitoClient()
        let store = InMemorySessionStore()
        let logger = SpyLogger()
        let service: CognitoAuthService

        init() {
            service = CognitoAuthService(client: client, store: store, logger: logger)
        }
    }

    private let credentials = TestFixtures.credentials
    /// The user the fake client describes: `sub` as id, the name derived from the email.
    private let expectedUser = AuthUser(id: "sub-1", displayName: "Jane Doe", email: TestFixtures.credentials.email)

    // MARK: Restore

    @Test func restoreWithoutACognitoSessionIsNilAndDropsAStaleCache() async throws {
        let harness = Harness()
        harness.store.stored = .signedIn(TestFixtures.session)

        #expect(try await harness.service.restoreSession() == nil)

        #expect(harness.store.stored == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Dropping cached session") })
    }

    @Test func restoreKeepsTheGuestChoice() async throws {
        let harness = Harness()
        harness.store.stored = .guest

        #expect(try await harness.service.restoreSession() == nil)
        #expect(harness.store.stored == .guest)
    }

    @Test func restoreWithASessionPrefersTheCachedUser() async throws {
        let harness = Harness()
        harness.client.signedIn = true
        harness.store.stored = .signedIn(TestFixtures.session)

        #expect(try await harness.service.restoreSession() == TestFixtures.session)
    }

    @Test func restoreWithASessionAndNoCacheLoadsAndCachesTheUser() async throws {
        let harness = Harness()
        harness.client.signedIn = true

        let session = try await harness.service.restoreSession()

        #expect(session?.user == expectedUser)
        #expect(harness.store.stored == .signedIn(AuthSession(user: expectedUser)))
    }

    // MARK: Sign-in

    @Test func emailSignInLoadsTheUserAndCachesTheSession() async throws {
        let harness = Harness()

        let session = try await harness.service.signIn(with: .email(credentials))

        #expect(session.user == expectedUser)
        #expect(harness.client.signIns == [credentials])
        #expect(harness.store.stored == .signedIn(session))
    }

    @Test func aPoolWithoutAnEmailAttributeNamesTheUserAfterTheUsername() async throws {
        let harness = Harness()
        harness.client.emailResult = .success(nil)
        harness.client.user = CognitoUser(sub: "sub-2", username: "pat_lee")

        let session = try await harness.service.signIn(with: .email(credentials))

        #expect(session.user == AuthUser(id: "sub-2", displayName: "Pat Lee", email: nil))
    }

    @Test func unconfirmedSignInAsksForConfirmation() async {
        let harness = Harness()
        harness.client.signInResult = .success(.confirmationRequired)

        await #expect(throws: AppError.emailNotConfirmed) { try await harness.service.signIn(with: .email(credentials)) }
        #expect(harness.store.stored == nil)
    }

    @Test func unsupportedSignInStepFailsAndIsLogged() async {
        let harness = Harness()
        harness.client.signInResult = .success(.otherStep("confirmSignInWithTOTPCode"))

        await #expect(throws: AppError.authFailed(provider: .email)) {
            try await harness.service.signIn(with: .email(credentials))
        }
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("confirmSignInWithTOTPCode") })
    }

    @Test(arguments: [AuthProvider.apple, .google])
    func providersAreNotAvailableYet(provider: AuthProvider) async {
        let harness = Harness()

        await #expect(throws: AppError.providerUnavailable(provider: provider.kind)) {
            try await harness.service.signIn(with: provider)
        }
        #expect(harness.client.signIns.isEmpty)
    }

    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let errorCases: [(CognitoClientError, AppError)] = [
        (.notAuthorized, .invalidCredentials), (.userNotFound, .invalidCredentials), (.invalidPassword, .invalidCredentials),
        (.userNotConfirmed, .emailNotConfirmed), (.usernameExists, .emailTaken),
        (.codeMismatch, .invalidConfirmationCode), (.codeExpired, .invalidConfirmationCode),
        (.limitExceeded, .tooManyAttempts), (.network, .network), (.sessionExpired, .sessionExpired),
        (.other("InvalidParameterException"), .authFailed(provider: .email)),
    ]

    @Test(arguments: errorCases)
    func clientErrorsBecomeAppErrors(clientError: CognitoClientError, expected: AppError) async {
        let harness = Harness()
        harness.client.signInResult = .failure(clientError)
        harness.client.signUpResult = .failure(clientError)
        harness.client.confirmError = clientError

        await #expect(throws: expected) { try await harness.service.signIn(with: .email(credentials)) }
        await #expect(throws: expected) {
            try await harness.service.signUp(email: credentials.email, password: credentials.password)
        }
        await #expect(throws: expected) { try await harness.service.confirmSignUp(email: credentials.email, code: "123456") }
    }

    // MARK: Sign-up, confirm, resend, sign-out

    @Test func signUpReportsWhetherConfirmationIsNeeded() async throws {
        let harness = Harness()

        let (email, password) = (credentials.email, credentials.password)

        #expect(try await harness.service.signUp(email: email, password: password) == .confirmationRequired)
        harness.client.signUpResult = .success(.done)
        #expect(try await harness.service.signUp(email: email, password: password) == .signedUp)
        #expect(harness.client.signUps == [credentials, credentials])
    }

    @Test func confirmAndResendReachTheClient() async throws {
        let harness = Harness()

        try await harness.service.confirmSignUp(email: credentials.email, code: "123456")
        try await harness.service.resendConfirmationCode(email: credentials.email)

        #expect(harness.client.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.client.resendEmails == [credentials.email])
    }

    @Test func signOutClearsTheCacheBeforeAskingThePool() async throws {
        let harness = Harness()
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.client.signOutError = .network

        await #expect(throws: AppError.network) { try await harness.service.signOut() }

        #expect(harness.store.stored == nil)
        #expect(harness.client.signOutCount == 1)
    }

    // MARK: Token

    @Test func accessTokenComesFromTheClient() async {
        let harness = Harness()
        #expect(await harness.service.accessToken() == "access-token")

        harness.client.tokenResult = .success(nil)
        #expect(await harness.service.accessToken() == nil)
    }

    /// The realtime reconnect asks the pool for a new token; the answer, or its absence, is the client's.
    @Test func freshAccessTokenForcesARefreshAndNeverThrows() async {
        let harness = Harness()
        #expect(await harness.service.freshAccessToken() == "fresh-access-token")
        #expect(harness.client.freshTokenRequestCount == 1)

        harness.client.freshTokenResult = .failure(.network)
        #expect(await harness.service.freshAccessToken() == nil)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("No fresh access token") })
    }

    /// A token failure is the backend's to judge (401 -> session expired), so the request still goes out, and a log
    /// line remembers why it went without one.
    @Test func accessTokenFailureIsNilAndLoggedNeverThrown() async {
        let harness = Harness()
        harness.client.tokenResult = .failure(.sessionExpired)

        #expect(await harness.service.accessToken() == nil)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("No access token") })
    }
}
