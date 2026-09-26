import CryptoKit
import Foundation

nonisolated enum MockAuthBehavior: Equatable, Sendable {
    case succeed
    case fail(AppError)
    /// Sign-up answers `.confirmationRequired` and only this code confirms, like a pool that emails a code.
    case requireConfirmation(code: String)
}

/// Stand-in for Cognito. Simulates latency and persists a fake session the way Amplify keeps tokens.
final class MockAuthService: AuthService {
    private let behavior: MockAuthBehavior
    private let delay: Duration
    private let store: any SessionStore
    /// `-mock-user-id`: every sign-in yields this user, so two simulators can act as two people.
    private let userIDOverride: String?
    private let sleep: Sleep

    init(behavior: MockAuthBehavior = .succeed,
         delay: Duration = AppConfig.Auth.mockSignInDelay,
         store: any SessionStore,
         userIDOverride: String? = nil,
         sleep: @escaping Sleep = systemSleep) {
        self.behavior = behavior
        self.delay = delay
        self.store = store
        self.userIDOverride = userIDOverride
        self.sleep = sleep
    }

    func restoreSession() async throws -> AuthSession? {
        if case .signedIn(let session) = store.load() { return session }
        return nil
    }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        try await simulateNetwork()
        let session = AuthSession(user: userIDOverride.map(MockUsers.user(withID:)) ?? MockUsers.user(for: provider))
        store.save(.signedIn(session))
        return session
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        try await simulateNetwork()
        guard CredentialsValidator.isValidEmail(email), CredentialsValidator.isValidPassword(password) else {
            throw AppError.invalidCredentials
        }
        if case .requireConfirmation = behavior { return .confirmationRequired }
        return .signedUp
    }

    func confirmSignUp(email: String, code: String) async throws {
        try await simulateNetwork()
        if case .requireConfirmation(let expected) = behavior, code != expected {
            throw AppError.invalidConfirmationCode
        }
    }

    func resendConfirmationCode(email: String) async throws {
        try await simulateNetwork()
    }

    func signOut() async throws {
        try await simulateNetwork()
        store.clear()
    }

    private func simulateNetwork() async throws {
        if delay > .zero { try await sleep(delay) }
        if case .fail(let error) = behavior { throw error }
    }
}

/// Deterministic fake identities so previews and tests are stable.
nonisolated enum MockUsers {
    static func user(for provider: AuthProvider) -> AuthUser {
        switch provider {
        case .apple:
            AuthUser(id: "mock-apple", displayName: "Apple Tester", email: email(for: "apple"))
        case .google:
            AuthUser(id: "mock-google", displayName: "Google Tester", email: email(for: "google"))
        case .email(let credentials):
            AuthUser(id: "mock-email-\(opaqueID(for: credentials.email))",
                     displayName: AuthUser.displayName(fromEmail: credentials.email),
                     email: credentials.email)
        }
    }

    /// The user a chosen id stands for: the id as the mailbox, the display name derived from it like an email sign-in's.
    static func user(withID id: String) -> AuthUser {
        let email = email(for: id)
        return AuthUser(id: id, displayName: AuthUser.displayName(fromEmail: email), email: email)
    }

    private static func email(for localPart: String) -> String {
        "\(localPart)@\(AppConfig.Auth.mockEmailDomain)"
    }

    /// User ids end up in log lines, so they must never embed the email itself.
    private static func opaqueID(for email: String) -> String {
        let digest = SHA256.hash(data: Data(email.lowercased().utf8))
        return digest.prefix(AppConfig.Auth.mockUserIDDigestBytes).map { String(format: "%02x", $0) }.joined()
    }
}
