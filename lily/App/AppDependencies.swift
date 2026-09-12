import Foundation

/// Composition root. The only place that knows concrete implementations.
final class AppDependencies {
    let logger: any Logging
    let errorCenter: ErrorCenter
    let sessionStore: any SessionStore
    let authService: any AuthService
    let sessionController: SessionController
    /// The user the API client and the event screens act for; answers from `sessionController`.
    let identity: any IdentityProvider
    let eventRepository: any EventRepository
    let profileRepository: any ProfileRepository
    let locationService: any LocationService
    let eventChanges = EventChangeTracker()

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         identity: SessionIdentityProvider = SessionIdentityProvider(),
         eventRepository: any EventRepository,
         profileRepository: any ProfileRepository,
         locationService: any LocationService) {
        self.logger = logger
        self.errorCenter = ErrorCenter(logger: logger)
        self.sessionStore = sessionStore
        self.authService = authService
        self.identity = identity
        self.eventRepository = eventRepository
        self.profileRepository = profileRepository
        self.locationService = locationService
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   profileRepository: profileRepository,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
        // The repositories were built around `identity` before the controller existed; close the loop.
        identity.session = sessionController
    }

    /// Production wiring. Swap `MockAuthService` for `CognitoAuthService` once Amplify is configured.
    /// Launch arguments are read in debug builds only (`AppConfig.LaunchArguments.isHonored`); a release build
    /// ignores them, so nobody can start it as a guest or on mock data from the outside.
    static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [],
                            defaults: UserDefaults = .standard) -> AppDependencies {
        let logger = OSLogLogger()
        let store = makeSessionStore(arguments: arguments, defaults: defaults, logger: logger)
        let identity = SessionIdentityProvider()
        let repositories = makeRepositories(arguments: arguments, identity: identity, logger: logger)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: makeAuthService(arguments: arguments, store: store, logger: logger),
                               identity: identity,
                               eventRepository: repositories.events,
                               profileRepository: repositories.profile,
                               locationService: makeLocationService(arguments: arguments, logger: logger))
    }

    /// Isolated in-memory wiring for previews and tests.
    static func makeMock(authBehavior: MockAuthBehavior = .succeed) -> AppDependencies {
        let logger = OSLogLogger()
        let defaults = UserDefaults(suiteName: AppConfig.Storage.previewSuitePrefix + UUID().uuidString) ?? .standard
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        let repositories = Repositories.mock(logger: logger)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(behavior: authBehavior, delay: .zero, store: store),
                               eventRepository: repositories.events,
                               profileRepository: repositories.profile,
                               locationService: MockLocationService())
    }

    /// Explore starts from the default filter (10 km around the user); a list without a filter button, such as
    /// My Events, must never hide a game, so it starts from `.everything`.
    func makeEventListViewModel(scope: EventScope) -> EventListViewModel {
        EventListViewModel(scope: scope,
                           repository: eventRepository,
                           identity: identity,
                           locationService: locationService,
                           changes: eventChanges,
                           errorCenter: errorCenter,
                           logger: logger,
                           initialFilter: scope == .upcoming ? EventFilter() : .everything)
    }

    func makeEventDetailViewModel(for event: SportEvent,
                                  onChange: @escaping @MainActor (SportEvent) -> Void) -> EventDetailViewModel {
        EventDetailViewModel(event: event,
                             repository: eventRepository,
                             identity: identity,
                             errorCenter: errorCenter,
                             logger: logger,
                             onChange: onChange)
    }

    /// Applies the session launch arguments (`-reset-session`, `-start-as-guest`) to the persisted choice.
    private static func makeSessionStore(arguments: [String],
                                         defaults: UserDefaults,
                                         logger: any Logging) -> UserDefaultsSessionStore {
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        if arguments.contains(AppConfig.LaunchArguments.resetSession) {
            logger.info(.auth, "Launch argument requested a session reset")
            store.clear()
        }
        if arguments.contains(AppConfig.LaunchArguments.startAsGuest) {
            logger.info(.auth, "Launch argument requested guest mode")
            store.save(.guest)
        }
        return store
    }

    private static func makeAuthService(arguments: [String], store: any SessionStore, logger: any Logging) -> MockAuthService {
        guard arguments.contains(AppConfig.LaunchArguments.mockAuthFail) else {
            return MockAuthService(behavior: .succeed, store: store)
        }
        logger.info(.auth, "Launch argument requested failing mock auth")
        return MockAuthService(behavior: .fail(.network), store: store)
    }

    private static func makeLocationService(arguments: [String], logger: any Logging) -> any LocationService {
        arguments.contains(AppConfig.LaunchArguments.mockLocation)
            ? MockLocationService()
            : CachedLocationService(upstream: CoreLocationService(logger: logger), logger: logger)
    }

    private static func makeRepositories(arguments: [String],
                                         identity: any IdentityProvider,
                                         logger: any Logging) -> Repositories {
        guard arguments.contains(AppConfig.LaunchArguments.mockEvents) else {
            return .remote(identity: identity, logger: logger)
        }
        logger.info(.events, "Launch argument requested mock events")
        return .mock(logger: logger)
    }
}

/// The data layer comes as a pair: both repositories talk to the same backend, or both stay in memory.
private struct Repositories {
    let events: any EventRepository
    let profile: any ProfileRepository

    static func remote(identity: any IdentityProvider, logger: any Logging) -> Repositories {
        let client = URLSessionAPIClient(identity: identity, logger: logger)
        return Repositories(events: RemoteEventRepository(client: client), profile: RemoteProfileRepository(client: client))
    }

    static func mock(logger: any Logging) -> Repositories {
        Repositories(events: MockEventRepository(logger: logger), profile: MockProfileRepository(logger: logger))
    }
}
