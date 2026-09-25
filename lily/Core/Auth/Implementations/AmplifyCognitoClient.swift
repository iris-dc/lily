import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import Foundation

/// `CognitoClient` over Amplify: the only file that sees Amplify's types. Amplify is process-wide and refuses a second
/// `configure`, so one shared task configures it on the first call, never at construction: the composition root builds
/// this client in unit tests too, and nothing there may reach Amplify.
final class AmplifyCognitoClient: CognitoClient {
    private static var configuring: Task<Void, any Error>?
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func isSignedIn() async throws -> Bool {
        try await ready()
        return try await mapped { try await Amplify.Auth.fetchAuthSession().isSignedIn }
    }

    /// Amplify refreshes the tokens itself when they are due; a signed-out session yields no token rather than an error.
    func accessToken() async throws -> String? {
        try await accessToken(options: nil)
    }

    /// `forceRefresh` makes Amplify go to the pool even for a token that is still valid, which the realtime reconnect
    /// before expiry needs: without it the same token would come back and the connection would be renewed for nothing.
    func freshAccessToken() async throws -> String? {
        try await accessToken(options: AuthFetchSessionRequest.Options(forceRefresh: true))
    }

    private func accessToken(options: AuthFetchSessionRequest.Options?) async throws -> String? {
        try await ready()
        return try await mapped {
            let session = try await Amplify.Auth.fetchAuthSession(options: options)
            guard session.isSignedIn, let tokens = session as? AuthCognitoTokensProvider else { return nil }
            return try tokens.getCognitoTokens().get().accessToken
        }
    }

    func currentUser() async throws -> CognitoUser {
        try await ready()
        return try await mapped {
            let user = try await Amplify.Auth.getCurrentUser()
            return CognitoUser(sub: user.userId, username: user.username)
        }
    }

    func fetchEmail() async throws -> String? {
        try await ready()
        return try await mapped { try await Amplify.Auth.fetchUserAttributes().first { $0.key == .email }?.value }
    }

    func signIn(username: String, password: String) async throws -> CognitoSignInStep {
        try await ready()
        return try await mapped {
            // Amplify answers `invalidState` to a sign-in while a session exists; a stale one must not lock the user out.
            if try await Amplify.Auth.fetchAuthSession().isSignedIn {
                logger.info(.auth, "Signing out a stale Cognito session before sign-in")
                _ = await Amplify.Auth.signOut()
            }
            return Self.step(of: try await Amplify.Auth.signIn(username: username, password: password).nextStep)
        }
    }

    func signUp(email: String, password: String) async throws -> CognitoSignUpStep {
        try await ready()
        return try await mapped {
            let options = AuthSignUpRequest.Options(userAttributes: [AuthUserAttribute(.email, value: email)])
            let result = try await Amplify.Auth.signUp(username: email, password: password, options: options)
            return result.isSignUpComplete ? .done : .confirmationRequired
        }
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await ready()
        try await mapped { _ = try await Amplify.Auth.confirmSignUp(for: email, confirmationCode: code) }
    }

    func resendCode(email: String) async throws {
        try await ready()
        try await mapped { _ = try await Amplify.Auth.resendSignUpCode(for: email) }
    }

    /// A partial sign-out (tokens not revoked at the pool) still ended the local session, which is what the app needs.
    func signOut() async throws {
        try await ready()
        switch await Amplify.Auth.signOut() as? AWSCognitoSignOutResult {
        case .failed(let error): throw CognitoClientError(error)
        case .partial: logger.warning(.auth, "Cognito sign-out completed locally only")
        case .complete, .none: break
        }
    }

    private func ready() async throws {
        if Self.configuring == nil {
            Self.configuring = Task { try Self.configure() }
        }
        do {
            try await Self.configuring?.value
        } catch {
            throw CognitoClientError.other("Amplify configuration failed: \(error)")
        }
    }

    private static func configure() throws {
        try Amplify.add(plugin: AWSCognitoAuthPlugin())
        let plugin = try JSONDecoder().decode(JSONValue.self, from: AmplifyConfigurationBuilder.cognitoPluginJSON())
        let auth = AuthCategoryConfiguration(plugins: [AmplifyConfigurationBuilder.pluginKey: plugin])
        try Amplify.configure(AmplifyConfiguration(auth: auth))
    }

    private func mapped<Value>(_ operation: () async throws -> Value) async throws -> Value {
        do {
            return try await operation()
        } catch {
            throw CognitoClientError(error)
        }
    }

    /// Only the case name goes into `.otherStep`: the associated values carry the code's delivery destination.
    private static func step(of nextStep: AuthSignInStep) -> CognitoSignInStep {
        switch nextStep {
        case .done: .done
        case .confirmSignUp: .confirmationRequired
        default: .otherStep(Mirror(reflecting: nextStep).children.first?.label ?? String(describing: nextStep))
        }
    }
}

private extension CognitoClientError {
    /// Amplify's canned descriptions name the condition, never the user, so they are safe to carry into the log.
    init(_ error: any Error) {
        guard let authError = error as? AuthError else {
            self = error is URLError ? .network : .other(String(describing: type(of: error)))
            return
        }
        switch authError {
        case .notAuthorized: self = .notAuthorized
        case .sessionExpired, .signedOut: self = .sessionExpired
        case .service, .unknown, .validation, .configuration, .invalidState:
            self = Self(underlying: authError.underlyingError, description: authError.errorDescription)
        }
    }

    private init(underlying: (any Error)?, description: String) {
        guard let cognitoError = underlying as? AWSCognitoAuthError else {
            self = underlying is URLError ? .network : .other(description)
            return
        }
        switch cognitoError {
        case .userNotFound: self = .userNotFound
        case .userNotConfirmed: self = .userNotConfirmed
        case .usernameExists, .aliasExists: self = .usernameExists
        case .invalidPassword: self = .invalidPassword
        case .codeMismatch: self = .codeMismatch
        case .codeExpired: self = .codeExpired
        case .limitExceeded, .limitExceededException, .requestLimitExceeded, .failedAttemptsLimitExceeded: self = .limitExceeded
        case .network: self = .network
        default: self = .other(description)
        }
    }
}
