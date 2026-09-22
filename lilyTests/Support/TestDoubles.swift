import Foundation
import Synchronization
import Testing
@testable import lily

/// Records log lines so tests can assert on key events.
@MainActor
final class SpyLogger: Logging {
    struct Entry {
        let level: LogLevel
        let category: LogCategory
        let message: String
    }

    private(set) var entries: [Entry] = []

    func log(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        entries.append(Entry(level: level, category: category, message: message))
    }

    /// Messages of one category, optionally narrowed to one level.
    func messages(in category: LogCategory, at level: LogLevel? = nil) -> [String] {
        entries.filter { $0.category == category && (level == nil || $0.level == level) }.map(\.message)
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
    var signInResult: Result<AuthSession, AppError> = .success(TestFixtures.session)
    var signUpOutcome: SignUpOutcome = .signedUp
    var signUpError: AppError?
    var confirmError: AppError?
    var resendError: AppError?
    var signOutError: AppError?
    /// Simulated latency before sign-in and sign-up answer; a suspension point, so cancellation can be observed.
    var delay: Duration = .zero
    private(set) var signInProviders: [AuthProvider] = []
    private(set) var signUpRequests: [EmailCredentials] = []
    private(set) var confirmations: [ConfirmationRequest] = []
    private(set) var resendEmails: [String] = []
    private(set) var signOutCount = 0

    struct ConfirmationRequest: Equatable {
        let email: String
        let code: String
    }

    func restoreSession() async throws -> AuthSession? { try restoreResult.get() }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        signInProviders.append(provider)
        try await simulateLatency()
        return try signInResult.get()
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        signUpRequests.append(EmailCredentials(email: email, password: password))
        try await simulateLatency()
        if let signUpError { throw signUpError }
        return signUpOutcome
    }

    func confirmSignUp(email: String, code: String) async throws {
        confirmations.append(ConfirmationRequest(email: email, code: code))
        try await simulateLatency()
        if let confirmError { throw confirmError }
    }

    func resendConfirmationCode(email: String) async throws {
        resendEmails.append(email)
        try await simulateLatency()
        if let resendError { throw resendError }
    }

    private func simulateLatency() async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
    }

    func signOut() async throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }
}

@MainActor
final class FakeProfileRepository: ProfileRepository {
    var error: AppError?
    /// Simulated latency, a suspension point so cancellation can be observed.
    var delay: Duration = .zero
    private(set) var syncedNames: [String] = []

    func syncDisplayName(_ name: String) async throws {
        syncedNames.append(name)
        if delay > .zero { try await Task.sleep(for: delay) }
        if let error { throw error }
    }
}

@MainActor
final class FakeIdentityProvider: IdentityProvider {
    var currentUserID: String?

    init(currentUserID: String? = nil) {
        self.currentUserID = currentUserID
    }
}

/// Builds a controller with fakes wired in; returns the collaborators for assertions.
@MainActor
struct SessionHarness {
    let auth = FakeAuthService()
    let store = InMemorySessionStore()
    let profile = FakeProfileRepository()
    let logger = SpyLogger()
    let errorCenter: ErrorCenter
    let controller: SessionController

    init() {
        errorCenter = ErrorCenter(logger: logger)
        controller = SessionController(authService: auth,
                                       sessionStore: store,
                                       profileRepository: profile,
                                       errorCenter: errorCenter,
                                       logger: logger)
    }
}

/// Builds a list view model over fakes. Every collaborator not given is created here, in the body: a main-actor
/// default argument would be evaluated off the actor.
@MainActor
func makeEventListViewModel(scope: EventScope = .upcoming,
                            repository: FakeEventRepository,
                            identity: FakeIdentityProvider? = nil,
                            locationService: (any LocationService)? = nil,
                            changes: EventChangeTracker? = nil,
                            errorCenter: ErrorCenter? = nil,
                            logger: SpyLogger? = nil,
                            now: @escaping () -> Date = { .now },
                            initialFilter: EventFilter = EventFilter()) -> EventListViewModel {
    EventListViewModel(scope: scope,
                       repository: repository,
                       identity: identity ?? FakeIdentityProvider(),
                       locationService: locationService ?? MockLocationService(),
                       changes: changes ?? EventChangeTracker(),
                       errorCenter: errorCenter ?? ErrorCenter(logger: SpyLogger()),
                       logger: logger ?? SpyLogger(),
                       now: now,
                       initialFilter: initialFilter)
}

/// Upper bound on the yields `settle(until:)` spends before it gives up and fails.
private let settleYieldLimit = 1_000

/// Yields to the main actor until `condition` holds, so a held request is observably in flight (or observably
/// dropped) before the test goes on. Bounded, so a regression fails at the call site instead of hanging.
@MainActor
func settle(until condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    var yields = 0
    while !condition() && yields < settleYieldLimit {
        await Task.yield()
        yields += 1
    }
    #expect(condition(), "condition still false after \(settleYieldLimit) yields", sourceLocation: sourceLocation)
}

/// Scripted location updates: yields the given fixes, then stays open (like CoreLocation) until cancelled,
/// or fails with `error` once the fixes are out. Records whether the consumer tore the stream down.
final class FakeLocationUpdateSource: LocationUpdateSource, Sendable {
    private let fixes: [LocationFix]
    private let error: (any Error)?
    private let terminated = Mutex(false)

    var wasTerminated: Bool { terminated.withLock { $0 } }

    init(fixes: [LocationFix] = [], error: (any Error)? = nil) {
        self.fixes = fixes
        self.error = error
    }

    func updates() -> AsyncThrowingStream<LocationFix, any Error> {
        AsyncThrowingStream { continuation in
            fixes.forEach { continuation.yield($0) }
            if let error { continuation.finish(throwing: error) }
            continuation.onTermination = { [self] _ in terminated.withLock { $0 = true } }
        }
    }
}

/// Counts requests and can hold them open until released, to test coalescing of concurrent callers.
@MainActor
final class FakeLocationService: LocationService {
    var result: Coordinate?
    /// While true, `currentLocation()` suspends until `release()`.
    var holdsRequests = false
    private(set) var callCount = 0
    private var held: [CheckedContinuation<Void, Never>] = []

    func currentLocation() async -> Coordinate? {
        callCount += 1
        if holdsRequests {
            await withCheckedContinuation { held.append($0) }
        }
        return result
    }

    func release() {
        let waiting = held
        held.removeAll()
        waiting.forEach { $0.resume() }
    }
}

/// Hand-advanced clock so TTL tests never sleep.
@MainActor
final class ManualClock {
    private(set) var now = ContinuousClock.now

    func advance(by duration: Duration) {
        now = now.advanced(by: duration)
    }
}
