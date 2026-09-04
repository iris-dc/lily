import CryptoKit
import Foundation

nonisolated enum MockAuthBehavior: Sendable {
    case succeed
    case fail(AppError)
}

/// Stand-in for Cognito. Simulates latency and persists a fake session the way Amplify keeps tokens.
final class MockAuthService: AuthService {
    private let behavior: MockAuthBehavior
    private let delay: Duration
    private let store: any SessionStore

    init(behavior: MockAuthBehavior = .succeed,
         delay: Duration = AppConfig.Auth.mockSignInDelay,
         store: any SessionStore) {
        self.behavior = behavior
        self.delay = delay
        self.store = store
    }

    func restoreSession() async throws -> AuthSession? {
        if case .signedIn(let session) = store.load() { return session }
        return nil
    }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        try await simulateNetwork()
        let session = AuthSession(user: MockUsers.user(for: provider), issuedAt: .now)
        store.save(.signedIn(session))
        return session
    }

    func signUp(email: String, password: String) async throws {
        try await simulateNetwork()
        guard CredentialsValidator.isValidEmail(email), CredentialsValidator.isValidPassword(password) else {
            throw AppError.invalidCredentials
        }
    }

    func signOut() async throws {
        try await simulateNetwork()
        store.clear()
    }

    private func simulateNetwork() async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
        if case .fail(let error) = behavior { throw error }
    }
}

/// Deterministic fake identities so previews and tests are stable.
nonisolated enum MockUsers {
    static func user(for provider: AuthProvider) -> AuthUser {
        switch provider {
        case .apple:
            AuthUser(id: "mock-apple", displayName: "Apple Tester", email: "apple@example.com")
        case .google:
            AuthUser(id: "mock-google", displayName: "Google Tester", email: "google@example.com")
        case .email(let credentials):
            AuthUser(id: "mock-email-\(opaqueID(for: credentials.email))",
                     displayName: displayName(fromEmail: credentials.email),
                     email: credentials.email)
        }
    }

    /// User ids end up in log lines, so they must never embed the email itself.
    private static func opaqueID(for email: String) -> String {
        let digest = SHA256.hash(data: Data(email.lowercased().utf8))
        return digest.prefix(AppConfig.Auth.mockUserIDDigestBytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func displayName(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.split(whereSeparator: { $0 == "." || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
