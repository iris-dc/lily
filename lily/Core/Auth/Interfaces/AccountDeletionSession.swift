import Foundation

/// The session side of the delete-account flow (the deletion contract), implemented by `SessionController` in
/// `+AccountDeletion`: the flow announces itself so racing 401s end nothing while the locked sheet is up, backs out
/// when the backend refused the request, and — only from the one-time acknowledgment's tap — runs the dedicated
/// account-deleted end.
protocol AccountDeletionSession: AnyObject {
    func beginAccountDeletion()
    func cancelAccountDeletion()
    func endDeletedSession() async
}
