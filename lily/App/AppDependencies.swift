import Foundation

/// Composition root. The only place that knows concrete implementations.
final class AppDependencies {
    let logger: any Logging
    let errorCenter: ErrorCenter
    let sessionStore: any SessionStore
    let authService: any AuthService
    let sessionController: SessionController
    let eventRepository: any EventRepository

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         eventRepository: any EventRepository) {
        self.logger = logger
        self.errorCenter = ErrorCenter(logger: logger)
        self.sessionStore = sessionStore
        self.authService = authService
        self.eventRepository = eventRepository
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
    }

    /// Production wiring. Swap `MockAuthService` for `CognitoAuthService` once Amplify is configured.
    static func makeDefault() -> AppDependencies {
        let logger = OSLogLogger()
        let store = UserDefaultsSessionStore()
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(store: store),
                               eventRepository: MockEventRepository(logger: logger))
    }

    /// Isolated in-memory wiring for previews and tests.
    static func makeMock(authBehavior: MockAuthBehavior = .succeed,
                         authDelay: Duration = .zero) -> AppDependencies {
        let logger = OSLogLogger()
        let defaults = UserDefaults(suiteName: AppConfig.Storage.previewSuitePrefix + UUID().uuidString) ?? .standard
        let store = UserDefaultsSessionStore(defaults: defaults)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(behavior: authBehavior, delay: authDelay, store: store),
                               eventRepository: MockEventRepository(logger: logger))
    }

    func makeEventListViewModel(scope: EventScope) -> EventListViewModel {
        EventListViewModel(scope: scope, repository: eventRepository, errorCenter: errorCenter, logger: logger)
    }
}
