import Foundation

nonisolated struct AuthSession: Codable, Hashable, Sendable {
    let user: AuthUser
}

/// What survives app relaunch: the guest choice, the signed-in user as last seen, or a sign-out the pool has not confirmed.
/// Tokens never live here: Cognito's stay in Amplify's keychain, and `CognitoAuthService` only trusts a cached `.signedIn`
/// while Amplify still has a session.
nonisolated enum StoredSession: Codable, Hashable, Sendable {
    case guest
    case signedIn(AuthSession)
    /// A sign-out the pool has not confirmed yet: saved before Amplify is asked, cleared once it answered, so a process
    /// killed in between finishes the sign-out on the next launch instead of restoring the session the user left.
    case signingOut
}
