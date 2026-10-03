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
            if case .signedIn = store.load() {
                logger.info(.auth, "Dropping cached session: Cognito has none")
                store.clear()
            }
            return nil
        }
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

    func signOut() async throws {
        store.clear()
        try await mapped { try await client.signOut() }
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
            try? await client.signOut()
            throw error
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
