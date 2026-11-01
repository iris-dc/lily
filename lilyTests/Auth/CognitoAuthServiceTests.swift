import Foundation
import Testing
@testable import lily

@MainActor
struct CognitoAuthServiceTests {
    @MainActor struct Harness {
        let client = FakeCognitoClient()
        let store = InMemorySessionStore()
        let logger = SpyLogger()
        let service: CognitoAuthService

        /// `languageCode` is what the service tells the pool, so a test can see it travel.
        init(languageCode: String = "en") {
            service = CognitoAuthService(client: client, store: store, languageCode: { languageCode }, logger: logger)
        }
    }

    private let credentials = TestFixtures.credentials
    /// The user the fake client describes: `sub` as id and the email attribute; the name is the backend's, not the pool's.
    private let expectedUser = AuthUser(id: "sub-1", email: TestFixtures.credentials.email)

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

    /// No name is made from the username either: the username is the pool's handle, never shown to anyone.
    @Test func aPoolWithoutAnEmailAttributeLeavesTheUserWithoutOne() async throws {
        let harness = Harness()
        harness.client.emailResult = .success(nil)
        harness.client.user = CognitoUser(sub: "sub-2", username: "pat_lee")

        let session = try await harness.service.signIn(with: .email(credentials))

        #expect(session.user == AuthUser(id: "sub-2", email: nil))
    }

    /// The pool accepted the sign-in, so a failure to read the user afterwards signs the pool out again: the app must
    /// never sit as a guest over a pool session, and the next launch must not sign in a user the app never reported.
    @Test func aFailedUserLoadAfterSignInSignsThePoolOutAgain() async {
        let harness = Harness()
        harness.client.emailResult = .failure(.network)

        await #expect(throws: AppError.network) { try await harness.service.signIn(with: .email(credentials)) }

        #expect(harness.client.signOutCount == 1)
        #expect(!harness.client.signedIn)
        #expect(harness.store.stored == nil)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("signing out") })
        #expect(!harness.logger.entries.contains { $0.message.contains(credentials.email) }, "no email in the log")
    }

    @Test func aFailedUserLoadOnRestoreSignsThePoolOutAgain() async {
        let harness = Harness()
        harness.client.signedIn = true
        harness.client.emailResult = .failure(.network)

        await #expect(throws: AppError.network) { try await harness.service.restoreSession() }

        #expect(harness.client.signOutCount == 1)
        #expect(harness.store.stored == nil)
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

    @Test func signUpAndResendTellThePoolTheAppsLanguage() async throws {
        let harness = Harness(languageCode: "uk")

        _ = try await harness.service.signUp(email: credentials.email, password: credentials.password)
        try await harness.service.resendConfirmationCode(email: credentials.email)

        #expect(harness.client.languageCodes == ["uk", "uk"])
    }

    @Test func confirmAndResendReachTheClient() async throws {
        let harness = Harness()

        try await harness.service.confirmSignUp(email: credentials.email, code: "123456")
        try await harness.service.resendConfirmationCode(email: credentials.email)

        #expect(harness.client.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.client.resendEmails == [credentials.email])
    }

    /// The cached user is gone either way; the marker stays so the next launch finishes what the pool refused.
    @Test func aRefusedPoolSignOutLeavesThePendingMarkerAndNoCache() async throws {
        let harness = Harness()
        harness.store.stored = .signedIn(TestFixtures.session)
        harness.client.signOutError = .network

        await #expect(throws: AppError.network) { try await harness.service.signOut() }

        #expect(harness.store.stored == .signingOut)
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

    /// The first refusal is reported (the root ends the session); the parallel requests that hit the same dead token say
    /// nothing more, and a token that comes back arms the report again.
    @Test func aDeadRefreshTokenReportsTheExpiryOnceUntilATokenComesBack() async {
        let harness = Harness()
        var reports = 0
        harness.service.onSessionExpired = { reports += 1 }
        harness.client.tokenResult = .failure(.sessionExpired)
        harness.client.freshTokenResult = .failure(.sessionExpired)

        #expect(await harness.service.accessToken() == nil)
        #expect(await harness.service.accessToken() == nil)
        #expect(await harness.service.freshAccessToken() == nil)
        #expect(reports == 1)
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("No access token") })

        harness.client.tokenResult = .success("access-token")
        #expect(await harness.service.accessToken() == "access-token")
        harness.client.tokenResult = .failure(.sessionExpired)
        #expect(await harness.service.accessToken() == nil)
        #expect(reports == 2)
    }

    /// An offline run keeps the session: only the pool's refusal of the refresh token is an expiry.
    @Test(arguments: [Result<String?, CognitoClientError>.failure(.network), .failure(.other("x")), .success(nil)])
    func aTokenFetchThatFailsForAnotherReasonReportsNoExpiry(result: Result<String?, CognitoClientError>) async {
        let harness = Harness()
        var reports = 0
        harness.service.onSessionExpired = { reports += 1 }
        harness.client.tokenResult = result

        #expect(await harness.service.accessToken() == nil)
        #expect(reports == 0)
    }

    /// `.authFailed` says nothing about why; the pool's condition text is the one line that does, with no email in it.
    @Test func anUnnamedPoolFailureIsLoggedWithItsDescription() async {
        let harness = Harness()
        harness.client.signInResult = .failure(.other("InvalidParameterException"))

        await #expect(throws: AppError.authFailed(provider: .email)) {
            try await harness.service.signIn(with: .email(credentials))
        }

        let warnings = harness.logger.messages(in: .auth, at: .warning)
        #expect(warnings.count == 1 && warnings.allSatisfy { $0.contains("InvalidParameterException") })
        #expect(!harness.logger.entries.contains { $0.message.contains(credentials.email) }, "no email in the log")
    }
}
