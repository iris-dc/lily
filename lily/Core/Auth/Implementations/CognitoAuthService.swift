import Foundation

/// `AuthService` over the Cognito user pool. Amplify holds the tokens; this keeps the signed-in user in the
/// `SessionStore` so a relaunch shows the profile without a round trip.
final class CognitoAuthService: AuthService, AuthTokenProvider {
    private let client: any CognitoClient
    private let store: any SessionStore
    private let languageCode: () -> String
    private let logger: any Logging

    /// `languageCode` is the app's language at the time of a sign-up or resend, for the pool's mail.
    init(client: any CognitoClient,
         store: any SessionStore,
         languageCode: @escaping () -> String = { AppLanguage.systemChoice().code },
         logger: any Logging) {
        self.client = client
        self.store = store
        self.languageCode = languageCode
        self.logger = logger
    }

    func restoreSession() async throws -> AuthSession? {
        guard try await mapped({ try await client.isSignedIn() }) else {
            dropStoreLeftWithoutAPoolSession()
            return nil
        }
        if await endsLeftoverPoolSession() { return nil }
        guard await refreshTokenIsAlive() else { return nil }
        if case .signedIn(let session) = store.load() { return session }
        return try await loadAndCacheSession()
    }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        guard case .email(let credentials) = provider else { throw AppError.providerUnavailable(provider: provider.kind) }
        let step = try await mapped { try await client.signIn(username: credentials.email, password: credentials.password) }
        switch step {
        case .done:
            return try await loadAndCacheSession()
        case .confirmationRequired:
            throw AppError.emailNotConfirmed
        case .otherStep(let name):
            logger.warning(.auth, "Sign-in stopped at an unsupported step: \(name)")
            throw AppError.authFailed(provider: .email)
        }
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        switch try await mapped({ try await client.signUp(email: email, password: password, languageCode: languageCode()) }) {
        case .done: .signedUp
        case .confirmationRequired: .confirmationRequired
        }
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await mapped { try await client.confirmSignUp(email: email, code: code) }
    }

    func resendConfirmationCode(email: String) async throws {
        try await mapped { try await client.resendCode(email: email, languageCode: languageCode()) }
    }

    /// The marker is cleared only once the client returned, and only while it is still there: a guest choice or a new
    /// sign-in stored meanwhile stands.
    func signOut() async throws {
        store.save(.signingOut)
        try await mapped { try await client.signOut() }
        clearPendingSignOut()
    }

    private func clearPendingSignOut() {
        if store.load() == .signingOut { store.clear() }
    }

    /// Never throws: a request without a token is answered 401 by the backend, which is the one place that decides.
    func accessToken() async -> String? {
        await token("access token") { try await client.accessToken() }
    }

    func freshAccessToken() async -> String? {
        await token("fresh access token") { try await client.freshAccessToken() }
    }

    private func token(_ kind: String, _ fetch: () async throws -> String?) async -> String? {
        do {
            return try await fetch()
        } catch {
            logger.warning(.auth, "No \(kind): \(error)")
            return nil
        }
    }

    /// No pool session: a cached user is stale and a pending sign-out is complete, so both go; a guest choice stands.
    private func dropStoreLeftWithoutAPoolSession() {
        switch store.load() {
        case .signedIn:
            logger.info(.auth, "Dropping cached session: Cognito has none")
            store.clear()
        case .signingOut:
            logger.info(.auth, "Sign-out already complete at the pool, marker cleared")
            store.clear()
        case .guest, nil:
            break
        }
    }

    /// A sign-out marker or a guest choice next to a pool session means a sign-out never reached Amplify's keychain, or
    /// a sign-in was killed between the pool's acceptance and the user read. The pool session is ended and the stored
    /// choice stands, so a guest signs in again rather than waking up signed in.
    private func endsLeftoverPoolSession() async -> Bool {
        switch store.load() {
        case .signingOut:
            logger.info(.auth, "Finishing a sign-out interrupted before the pool was told")
            if await signOutOfPool(after: "an interrupted sign-out") { clearPendingSignOut() }
            return true
        case .guest:
            logger.info(.auth, "Ending a pool session left behind a guest choice")
            await signOutOfPool(after: "a guest choice")
            return true
        case .signedIn, nil:
            return false
        }
    }

    /// Amplify keeps `isSignedIn` true after the refresh token expired; only a token request tells. Any other failure
    /// (offline) keeps the session: the backend's 401 is the one place that decides then.
    private func refreshTokenIsAlive() async -> Bool {
        do {
            _ = try await mapped { try await client.accessToken() }
            return true
        } catch AppError.sessionExpired {
            logger.warning(.auth, "Dropping cached session: the refresh token expired")
            if case .signedIn = store.load() { store.clear() }
            await signOutOfPool(after: "an expired refresh token")
            return false
        } catch {
            logger.info(.auth, "Could not check the session's token, keeping it: \(error)")
            return true
        }
    }

    /// Amplify has a session when this runs. When the user cannot be read, that session is signed out again before the
    /// error goes up, so the pool and the app never disagree about who is signed in.
    private func loadAndCacheSession() async throws -> AuthSession {
        do {
            let user = try await mapped { try await client.currentUser() }
            let email = try await mapped { try await client.fetchEmail() }
            let session = AuthSession(user: AuthUser(id: user.sub,
                                                     displayName: AuthUser.displayName(fromEmail: email ?? user.username),
                                                     email: email))
            store.save(.signedIn(session))
            return session
        } catch {
            logger.warning(.auth, "Could not load the signed-in user, signing out of the pool again: \(error)")
            await signOutOfPool(after: "a failed user load")
            throw error
        }
    }

    /// The compensating sign-out: the pool and the app must agree on who is signed in. Its own failure is logged
    /// because it is the one line that explains a later launch's silent sign-in. Answers whether the client returned.
    @discardableResult
    private func signOutOfPool(after step: String) async -> Bool {
        do {
            try await mapped { try await client.signOut() }
            return true
        } catch {
            logger.warning(.auth, "Pool sign-out after \(step) failed too: \(error)")
            return false
        }
    }

    private func mapped<Value>(_ operation: () async throws -> Value) async throws -> Value {
        do {
            return try await operation()
        } catch let error as CognitoClientError {
            throw error.appError
        }
    }
}

private extension CognitoClientError {
    /// `preventUserExistenceErrors` is on in the pool, so a missing user already reads as "not authorized" there too.
    var appError: AppError {
        switch self {
        case .notAuthorized, .userNotFound, .invalidPassword: .invalidCredentials
        case .userNotConfirmed: .emailNotConfirmed
        case .usernameExists: .emailTaken
        case .codeMismatch, .codeExpired: .invalidConfirmationCode
        case .limitExceeded: .tooManyAttempts
        case .network: .network
        case .sessionExpired: .sessionExpired
        case .other: .authFailed(provider: .email)
        }
    }
}
