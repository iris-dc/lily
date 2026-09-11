import Foundation

/// Answers with the signed-in user of the session. The API client is built before the `SessionController` (the
/// controller's own profile sync goes through that client), so the composition root links the two afterwards.
final class SessionIdentityProvider: IdentityProvider {
    weak var session: SessionController?

    var currentUserID: String? { session?.state.user?.id }
}
