import Foundation

/// Who is signed in, as the pool knows them: the `sub` and the email attribute. The name other players see is the
/// backend's profile (`ProfileStore`), chosen by the user, never derived from the email. A session stored before the
/// name moved there still carries a `displayName` key, which the decoder ignores.
nonisolated struct AuthUser: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let email: String?
}
