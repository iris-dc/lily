import Foundation

nonisolated struct EmailCredentials: Hashable, Sendable {
    let email: String
    let password: String
}

/// How a user authenticates. Maps 1:1 onto Amplify.Auth entry points later
/// (`signInWithWebUI(for:)` for Apple/Google, `signIn(username:password:)` for email).
nonisolated enum AuthProvider: Hashable, Sendable {
    case apple
    case google
    case email(EmailCredentials)

    /// Credential-free identity of the provider, safe to log and display.
    enum Kind: String, CaseIterable, Sendable {
        case apple, google, email

        var displayName: String {
            switch self {
            case .apple: "Apple"
            case .google: "Google"
            case .email: "Email"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .apple: .apple
        case .google: .google
        case .email: .email
        }
    }
}
