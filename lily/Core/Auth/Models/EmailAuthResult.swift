import Foundation

/// What `SessionController` answers to an email sign-in or sign-up. `.confirmationRequired` is not a failure and shows
/// no popup: the form switches to the code step instead.
nonisolated enum EmailAuthResult: Hashable, Sendable {
    case signedIn
    case confirmationRequired
    case failed
}
