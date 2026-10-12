import Foundation

/// What `SessionController` answers to a confirmation. `.confirmedButSignInFailed`: the pool accepted the code (a second
/// confirm would be refused as "not authorized"), only the sign-in after it failed and was shown; the form returns to
/// sign-in with its fields kept.
nonisolated enum ConfirmOutcome: Hashable, Sendable {
    case signedIn
    case confirmedButSignInFailed
    case failed
}
