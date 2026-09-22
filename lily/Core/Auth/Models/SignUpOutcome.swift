import Foundation

/// What the auth service answers to a sign-up.
nonisolated enum SignUpOutcome: Hashable, Sendable {
    /// The account can sign in right away.
    case signedUp
    /// The pool emailed a code; `confirmSignUp` must succeed before the first sign-in.
    case confirmationRequired
}
