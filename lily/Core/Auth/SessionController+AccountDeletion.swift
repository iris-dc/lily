import Foundation

/// The account-deleted session end (the deletion contract): distinct from a sign-out, because the backend's job
/// already erased the device rows and will erase the identity, so nothing may go out on the dead account's behalf;
/// distinct from an expired session, because the delete flow owns the popup-free teardown. The conformance is the
/// seam the delete flow's view model holds (`AccountDeletionSession`), so it never depends on the concrete controller.
extension SessionController: AccountDeletionSession {
    /// The delete-account flow started: expired-session reports stand down (the job's global sign-out kills live
    /// tokens early) until the flow lands in `endDeletedSession()` or backs out through `cancelAccountDeletion()`.
    func beginAccountDeletion() {
        isDeletingAccount = true
        logger.info(.auth, "Account deletion started: expired-session reports stand down")
    }

    /// The flow backed out before the backend accepted the deletion: expired sessions end the session again.
    func cancelAccountDeletion() {
        isDeletingAccount = false
        logger.info(.auth, "Account deletion abandoned: expired-session reports act again")
    }

    /// The dedicated account-deleted session end: observers get `sessionWillEndWithoutNetwork()` instead of the
    /// authenticated last word, no popup shows (the flow's acknowledgment was the word), and the pool sign-out still
    /// runs — it clears the local tokens so no later restore resurrects the dead session, and its refusal is only
    /// logged.
    func endDeletedSession() async {
        defer { isDeletingAccount = false }
        guard let user = state.user else {
            logger.debug(.auth, "Account-deleted end with nobody signed in")
            return
        }
        await holdingSignOutSlot {
            let ending = state
            await notifySessionWillEndWithoutNetwork()
            guard settleEndedSession(from: ending,
                                     saying: "Account deleted for user \(user.id): the session ended") else { return }
            await signOutOfPool()
        }
    }
}
