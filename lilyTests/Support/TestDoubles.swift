import Foundation
import Synchronization
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
    var signInResult: Result<AuthSession, AppError> = .success(TestFixtures.session)
    var signUpError: AppError?
    var signOutError: AppError?
    /// Simulated latency before sign-in and sign-up answer; a suspension point, so cancellation can be observed.
    var delay: Duration = .zero
    private(set) var signInProviders: [AuthProvider] = []
    private(set) var signUpRequests: [EmailCredentials] = []
    private(set) var signOutCount = 0

    func restoreSession() async throws -> AuthSession? { try restoreResult.get() }

    func signIn(with provider: AuthProvider) async throws -> AuthSession {
        signInProviders.append(provider)
        try await simulateLatency()
        return try signInResult.get()
    }

    func signUp(email: String, password: String) async throws {
        signUpRequests.append(EmailCredentials(email: email, password: password))
        try await simulateLatency()
        if let signUpError { throw signUpError }
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
final class FakeEventRepository: EventRepository {
    var result: Result<[SportEvent], AppError> = .success([])
    /// Thrown instead of `result` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    /// While true, `events(in:)` records the scope and then suspends until `releaseRequests()`.
    var holdsRequests = false
    /// Thrown by `join` and `leave` when set; otherwise they answer with the event from `result`, adjusted.
    var participationError: (any Error)?
    private var pending: [CheckedContinuation<Void, Never>] = []
    private(set) var requestedScopes: [EventScope] = []
    private(set) var joinedEventIDs: [String] = []
    private(set) var leftEventIDs: [String] = []

    func events(in scope: EventScope) async throws -> [SportEvent] {
        requestedScopes.append(scope)
        await holdIfRequested()
        if let thrownError { throw thrownError }
        return try result.get()
    }

    func join(eventId: String) async throws -> SportEvent {
        joinedEventIDs.append(eventId)
        return try await participationResult(for: eventId, delta: 1, isJoined: true)
    }

    func leave(eventId: String) async throws -> SportEvent {
        leftEventIDs.append(eventId)
        return try await participationResult(for: eventId, delta: -1, isJoined: false)
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        holdsRequests = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    private func holdIfRequested() async {
        if holdsRequests {
            await withCheckedContinuation { pending.append($0) }
        }
    }

    private func participationResult(for eventId: String, delta: Int, isJoined: Bool) async throws -> SportEvent {
        await holdIfRequested()
        if let participationError { throw participationError }
        guard let event = try result.get().first(where: { $0.id == eventId }) else { throw AppError.eventNotFound }
        return event.updatingParticipation(count: event.participantCount + delta, isJoined: isJoined)
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
