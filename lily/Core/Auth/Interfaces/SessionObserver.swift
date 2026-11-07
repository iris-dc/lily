import Foundation

/// Told by `SessionController` when the signed-in session is about to end and when it has ended, so state kept for the
/// app's lifetime on a user's behalf (stores, caches, connections) clears itself without `Core/Auth` having to name any
/// of it. `sessionWillEnd` runs while the user is still signed in, for a last request made on their behalf.
protocol SessionObserver: AnyObject {
    func sessionWillEnd() async
    /// The account-deleted end (the deletion contract): the backend's job already erased everything server-side and
    /// the tokens are dead, so an observer does only the local part of its last word. The default forwards to
    /// `sessionWillEnd()`, right for an observer whose last word never touches the network.
    func sessionWillEndWithoutNetwork() async
    func sessionDidEnd()
    /// The launch's check against the pool signed a user in that the cache did not have (a reinstall over a keychain
    /// that kept the tokens), told in the same turn as the state change, so nothing renders the state without it.
    func sessionDidRestore()
}

extension SessionObserver {
    func sessionWillEnd() async {}
    func sessionWillEndWithoutNetwork() async { await sessionWillEnd() }
    func sessionDidRestore() {}
}
