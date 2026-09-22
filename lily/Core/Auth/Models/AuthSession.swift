import Foundation

nonisolated struct AuthSession: Codable, Hashable, Sendable {
    let user: AuthUser
}

/// What survives app relaunch: the guest choice, or the signed-in user as last seen. Tokens never live here: Cognito's
/// stay in Amplify's keychain, and `CognitoAuthService` only trusts a cached `.signedIn` while Amplify still has a session.
nonisolated enum StoredSession: Codable, Hashable, Sendable {
    case guest
    case signedIn(AuthSession)
}
