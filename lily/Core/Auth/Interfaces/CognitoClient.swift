import Foundation

/// The signed-in Cognito user: `sub` is the id the backend reads from the token, `username` the pool's own name for
/// the user (a UUID when the pool signs in by email alias).
nonisolated struct CognitoUser: Hashable, Sendable {
    let sub: String
    let username: String
}

nonisolated enum CognitoSignInStep: Hashable, Sendable {
    case done
    /// The account exists but its email was never confirmed.
    case confirmationRequired
    /// A challenge the app does not handle (MFA, a new password, ...), named for the log.
    case otherStep(String)
}

nonisolated enum CognitoSignUpStep: Hashable, Sendable {
    case done
    case confirmationRequired
}

/// What can go wrong at the pool, without Amplify's types, so the service and its tests never import them.
nonisolated enum CognitoClientError: Error, Hashable, Sendable {
    case notAuthorized
    case userNotFound
    case userNotConfirmed
    case usernameExists
    case invalidPassword
    case codeMismatch
    case codeExpired
    case limitExceeded
    case network
    case sessionExpired
    case other(String)
}

/// The thin, mockable surface over Amplify that `CognitoAuthService` needs. Token refresh stays inside the implementation.
protocol CognitoClient {
    func isSignedIn() async throws -> Bool
    /// The current access token, refreshed if needed; `nil` when nobody is signed in.
    func accessToken() async throws -> String?
    func currentUser() async throws -> CognitoUser
    /// The signed-in user's verified email attribute, when the pool has one.
    func fetchEmail() async throws -> String?
    func signIn(username: String, password: String) async throws -> CognitoSignInStep
    func signUp(email: String, password: String) async throws -> CognitoSignUpStep
    func confirmSignUp(email: String, code: String) async throws
    func resendCode(email: String) async throws
    func signOut() async throws
}
