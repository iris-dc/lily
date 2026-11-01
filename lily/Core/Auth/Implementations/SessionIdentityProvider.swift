import Foundation

/// Answers with the signed-in user of the session. The repositories are built around this provider before the
/// `SessionController` exists, so the composition root links the two afterwards.
final class SessionIdentityProvider: IdentityProvider {
    weak var session: SessionController?

    var currentUserID: String? { session?.state.user?.id }
}
