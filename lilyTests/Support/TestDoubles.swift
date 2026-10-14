import Foundation
import Testing
@testable import lily

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
                            changes: ChangeTracker? = nil,
                            errorCenter: ErrorCenter? = nil,
                            recorder: SpyInteractionRecorder? = nil,
                            logger: SpyLogger? = nil,
                            now: @escaping () -> Date = { .now },
                            currencyCode: @escaping () -> String = { EventDraft.testCurrencyCode },
                            initialFilter: EventFilter = EventFilter(),
                            filterStore: (any EventFilterStore)? = nil) -> EventListViewModel {
    EventListViewModel(scope: scope,
                       repository: repository,
                       identity: identity ?? FakeIdentityProvider(),
                       locationService: locationService ?? MockLocationService(),
                       changes: changes ?? ChangeTracker(),
                       errorCenter: errorCenter ?? ErrorCenter(logger: SpyLogger()),
                       recorder: recorder ?? SpyInteractionRecorder(),
                       logger: logger ?? SpyLogger(),
                       now: now,
                       currencyCode: currencyCode,
                       initialFilter: initialFilter,
                       filterStore: filterStore ?? NoOpEventFilterStore())
}

/// A `UserDefaults` suite of its own, whose values go with the last reference, so tests that build the composition
/// root never share a stored session and unit runs leave no stored sessions, choices or filters in the simulator's
/// container (cfprefsd keeps an empty plist per suite behind).
final class TestDefaults: UserDefaults {
    let suiteName: String

    /// Names the suite `lily.tests.<id>`. Not `init?()`: that would override `UserDefaults.init()`, which is not failable.
    init?(id: UUID) {
        suiteName = "lily.tests.\(id.uuidString)"
        super.init(suiteName: suiteName)
    }

    deinit {
        // Through the standard instance, never `self`: a change posts a notification holding its receiver.
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

func makeTestDefaults() -> UserDefaults {
    TestDefaults(id: UUID())!
}

/// The mock composition root the App suites start from: reset, mock auth and mock events, signed out.
@MainActor
func makeMockDependencies(extraArguments: [String] = []) -> AppDependencies {
    AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                            AppConfig.LaunchArguments.mockAuth,
                                            AppConfig.LaunchArguments.mockEvents] + extraArguments,
                                defaults: makeTestDefaults())
}

/// `makeMockDependencies` with the mock Apple user signed in.
@MainActor
func makeSignedInMockDependencies(extraArguments: [String] = []) async -> AppDependencies {
    let dependencies = makeMockDependencies(extraArguments: extraArguments)
    await dependencies.sessionController.signIn(with: .apple)
    return dependencies
}

/// Upper bound on the yields the `settle` helpers spend before they give up and fail.
private let settleYieldLimit = 1_000

/// Yields to the main actor until `condition` holds, so a held request is observably in flight (or observably
/// dropped) before the test goes on. Bounded, so a regression fails at the call site instead of hanging.
@MainActor
func settle(until condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    // A synchronous condition cannot throw, so the awaited form never does here.
    try? await settle(untilAsync: condition, sourceLocation: sourceLocation)
}

/// `settle(until:)` for a condition that has to be awaited, such as a page read from a repository; the one yield
/// loop both helpers run.
@MainActor
func settle(untilAsync condition: () async throws -> Bool,
            sourceLocation: SourceLocation = #_sourceLocation) async throws {
    var yields = 0
    var settled = try await condition()
    while !settled && yields < settleYieldLimit {
        await Task.yield()
        yields += 1
        settled = try await condition()
    }
    #expect(settled, "condition still false after \(settleYieldLimit) yields", sourceLocation: sourceLocation)
}

/// Keeps the last saved filter and counts the saves, so a test can see what a view model wrote.
@MainActor
final class InMemoryEventFilterStore: EventFilterStore {
    var stored: EventFilter?
    private(set) var saveCount = 0

    init(stored: EventFilter? = nil) {
        self.stored = stored
    }

    func load() -> EventFilter? { stored }

    func save(_ filter: EventFilter) {
        stored = filter
        saveCount += 1
    }

    func clear() {
        stored = nil
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
