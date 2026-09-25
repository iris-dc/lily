import Foundation

/// Told by `SessionController` when the signed-in session has ended, so state kept for the app's lifetime on a user's
/// behalf (stores, caches, connections) clears itself without `Core/Auth` having to name any of it.
protocol SessionObserver: AnyObject {
    func sessionDidEnd()
}
