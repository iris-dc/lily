import Foundation

nonisolated struct AuthSession: Codable, Hashable, Sendable {
    let user: AuthUser
    let issuedAt: Date
}

/// What survives app relaunch. The real Cognito implementation keeps tokens in the Keychain itself,
/// so in production this only ever holds `.guest`; the mock also persists its fake `.signedIn` session here.
nonisolated enum StoredSession: Codable, Hashable, Sendable {
    case guest
    case signedIn(AuthSession)
}
