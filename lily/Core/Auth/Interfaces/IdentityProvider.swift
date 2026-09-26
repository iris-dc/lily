import Foundation

/// Who the app acts for right now. Read at the moment of use, so a sign-in or sign-out shows on the very next call.
protocol IdentityProvider {
    /// The signed-in user's id (the Cognito `sub`), or `nil` for guests.
    var currentUserID: String? { get }
}

extension IdentityProvider {
    /// Whether an answer requested for `userID` is still the current caller's to keep. After a sign-out or a switch it
    /// belongs to whoever asked; `what` names it in the debug line that says so.
    func isStillCaller(_ userID: String, orDrop what: String, logger: any Logging) -> Bool {
        guard currentUserID == userID else {
            logger.debug(.cache, "\(what) for a previous caller dropped")
            return false
        }
        return true
    }
}
