import Foundation
@testable import lily

/// Records log lines so tests can assert on key events.
@MainActor
final class SpyLogger: Logging {
    private(set) var entries: [(level: LogLevel, category: LogCategory, message: String)] = []

    func log(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        entries.append((level, category, message))
    }

    func messages(in category: LogCategory) -> [String] {
        entries.filter { $0.category == category }.map(\.message)
    }
}

@MainActor
final class InMemorySessionStore: SessionStore {
    var stored: StoredSession?
    func load() -> StoredSession? { stored }
    func save(_ session: StoredSession) { stored = session }
    func clear() { stored = nil }
}

/// Scripted auth service with call recording.
@MainActor
final class FakeAuthService: AuthService {
    var restoreResult: Result<AuthSession?, AppError> = .success(nil)
    var signInResult: Result<AuthSession, AppError>
    var signUpError: AppError?
    var signOutError: AppError?
    private(set) var signInProviders: [AuthProvider.Kind] = []
    private(set) var signOutCount = 0

    init(signInResult: Result<AuthSession, AppError> = .success(TestFixtures.session)) {
        self.signInResult = signInResult
    }

    func restoreSession() async throws -> AuthSession? { try restoreResult.get() }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        signInProviders.append(provider.kind)
        return try signInResult.get()
    }

    func signUp(email: String, password: String) async throws {
        if let signUpError { throw signUpError }
    }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }
}

@MainActor
final class FakeEventRepository: EventRepository {
    var result: Result<[SportEvent], AppError> = .success([])
    private(set) var requestedScopes: [EventScope] = []

    func events(in scope: EventScope) async throws -> [SportEvent] {
        requestedScopes.append(scope)
        return try result.get()
    }
}

enum TestFixtures {
    static let user = AuthUser(id: "u-1", displayName: "Test Person", email: "test@example.com")
    static let session = AuthSession(user: user, issuedAt: Date(timeIntervalSince1970: 1_700_000_000))
    static let credentials = EmailCredentials(email: "jane.doe@example.com", password: "correct-horse")
}

/// Builds a controller with fakes wired in; returns the collaborators for assertions.
@MainActor
struct SessionHarness {
    let auth = FakeAuthService()
    let store = InMemorySessionStore()
    let logger = SpyLogger()
    let errorCenter: ErrorCenter
    let controller: SessionController

    init() {
        errorCenter = ErrorCenter(logger: logger)
        controller = SessionController(authService: auth, sessionStore: store, errorCenter: errorCenter, logger: logger)
    }
}
