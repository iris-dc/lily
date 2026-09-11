import Foundation

/// Composition root. The only place that knows concrete implementations.
final class AppDependencies {
    let logger: any Logging
    let errorCenter: ErrorCenter
    let sessionStore: any SessionStore
    let authService: any AuthService
    let sessionController: SessionController
    let eventRepository: any EventRepository
    let locationService: any LocationService

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         eventRepository: any EventRepository,
         locationService: any LocationService) {
        self.logger = logger
        self.errorCenter = ErrorCenter(logger: logger)
        self.sessionStore = sessionStore
        self.authService = authService
        self.eventRepository = eventRepository
        self.locationService = locationService
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
    }

    /// Production wiring. Swap `MockAuthService` for `CognitoAuthService` once Amplify is configured.
    static func makeDefault(arguments: [String] = CommandLine.arguments,
                            defaults: UserDefaults = .standard) -> AppDependencies {
        let logger = OSLogLogger()
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        if arguments.contains(AppConfig.LaunchArguments.resetSession) {
            logger.info(.auth, "Launch argument requested a session reset")
            store.clear()
        }
        if arguments.contains(AppConfig.LaunchArguments.startAsGuest) {
            logger.info(.auth, "Launch argument requested guest mode")
            store.save(.guest)
        }
        let locationService: any LocationService = arguments.contains(AppConfig.LaunchArguments.mockLocation)
            ? MockLocationService()
            : CachedLocationService(upstream: CoreLocationService(logger: logger), logger: logger)
        let authBehavior: MockAuthBehavior = arguments.contains(AppConfig.LaunchArguments.mockAuthFail)
            ? .fail(.network)
            : .succeed
        if case .fail = authBehavior { logger.info(.auth, "Launch argument requested failing mock auth") }
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(behavior: authBehavior, store: store),
                               eventRepository: MockEventRepository(logger: logger),
                               locationService: locationService)
    }

    /// Isolated in-memory wiring for previews and tests.
    static func makeMock(authBehavior: MockAuthBehavior = .succeed) -> AppDependencies {
        let logger = OSLogLogger()
        let defaults = UserDefaults(suiteName: AppConfig.Storage.previewSuitePrefix + UUID().uuidString) ?? .standard
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(behavior: authBehavior, delay: .zero, store: store),
                               eventRepository: MockEventRepository(logger: logger),
                               locationService: MockLocationService())
    }

    /// Explore starts from the default filter (10 km around the user); a list without a filter button, such as
    /// My Events, must never hide a game, so it starts from `.everything`.
    func makeEventListViewModel(scope: EventScope) -> EventListViewModel {
        EventListViewModel(scope: scope,
                           repository: eventRepository,
                           locationService: locationService,
                           errorCenter: errorCenter,
                           logger: logger,
                           initialFilter: scope == .upcoming ? EventFilter() : .everything)
    }
}
