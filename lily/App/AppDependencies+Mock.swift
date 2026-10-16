import Foundation

extension AppDependencies {
    /// Isolated in-memory wiring for previews and tests.
    static func makeMock(authBehavior: MockAuthBehavior = .succeed) -> AppDependencies {
        let logger = OSLogLogger()
        let defaults = UserDefaults(suiteName: AppConfig.Storage.previewSuitePrefix + UUID().uuidString) ?? .standard
        let store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        let identity = SessionIdentityProvider()
        let repositories = Repositories.mock(identity: identity, logger: logger)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: MockAuthService(behavior: authBehavior, delay: .zero, store: store),
                               identity: identity,
                               eventRepository: repositories.events,
                               profileRepository: repositories.profile,
                               feedbackRepository: repositories.feedback,
                               interactionRecorder: repositories.interactions,
                               locationService: MockLocationService(),
                               groupRepositories: repositories.groups,
                               pushRegistrar: repositories.pushRegistrar,
                               deviceRepository: repositories.devices,
                               defaults: defaults)
    }
}
