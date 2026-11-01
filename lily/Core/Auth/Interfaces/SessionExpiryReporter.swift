import Foundation

/// Tells the composition root, once per lost session, that the pool refused to refresh the token; the root decides what
/// ends. A role of its own rather than a hook on `AuthTokenProvider`, so the token read stays a plain read and its
/// fakes need no closure.
protocol SessionExpiryReporter: AnyObject {
    var onSessionExpired: () -> Void { get set }
}
