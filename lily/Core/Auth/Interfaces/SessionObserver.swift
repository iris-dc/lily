import Foundation

/// Told by `SessionController` when the signed-in session is about to end and when it has ended, so state kept for the
/// app's lifetime on a user's behalf (stores, caches, connections) clears itself without `Core/Auth` having to name any
/// of it. `sessionWillEnd` runs while the user is still signed in, for a last request made on their behalf.
protocol SessionObserver: AnyObject {
    func sessionWillEnd() async
    func sessionDidEnd()
    /// The launch's check against the pool signed a user in that the cache did not have (a reinstall over a keychain
    /// that kept the tokens), told in the same turn as the state change, so nothing renders the state without it.
    func sessionDidRestore()
}

extension SessionObserver {
    func sessionWillEnd() async {}
    func sessionDidRestore() {}
}
