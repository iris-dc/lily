import Foundation

/// Composition root. The only place that knows concrete implementations.
final class AppDependencies {
    let logger: any Logging
    let errorCenter: ErrorCenter
    let sessionStore: any SessionStore
    let authService: any AuthService
    /// Source of the Bearer token the API client sends; `nil` while auth is mocked.
    let tokenProvider: (any AuthTokenProvider)?
    let sessionController: SessionController
    /// The user the API client and the event screens act for; answers from `sessionController`.
    let identity: any IdentityProvider
    let eventRepository: any EventRepository
    let profileRepository: any ProfileRepository
    /// Where the event screens report their taps; the root view flushes it when the app goes to the background.
    let interactionRecorder: any InteractionRecorder
    let locationService: any LocationService
    let eventChanges = ChangeTracker()
    /// Groups, chat, inbox and moderation collaborators; see `AppDependencies+Groups.swift`.
    let groups: GroupDependencies

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         tokenProvider: (any AuthTokenProvider)? = nil,
         identity: SessionIdentityProvider = SessionIdentityProvider(),
         eventRepository: any EventRepository,
         profileRepository: any ProfileRepository,
         interactionRecorder: any InteractionRecorder,
         locationService: any LocationService,
         groupRepositories: GroupRepositories) {
        self.logger = logger
        self.errorCenter = ErrorCenter(logger: logger)
        self.sessionStore = sessionStore
        self.authService = authService
        self.tokenProvider = tokenProvider
        self.identity = identity
        self.eventRepository = eventRepository
        self.profileRepository = profileRepository
        self.interactionRecorder = interactionRecorder
        self.locationService = locationService
        self.groups = GroupDependencies(repositories: groupRepositories,
                                        identity: identity,
                                        tokenProvider: tokenProvider,
                                        errorCenter: errorCenter,
                                        logger: logger)
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   profileRepository: profileRepository,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
        // The repositories were built around `identity` before the controller existed; close the loop.
        identity.session = sessionController
        groups.sessionObservers.forEach(sessionController.addObserver)
    }

    /// Production wiring: Cognito through Amplify, whose access token the API client sends, unless a launch argument
    /// asks for the mock. Launch arguments are read in debug builds only (`AppConfig.LaunchArguments.isHonored`); a
    /// release build ignores them, so nobody can start it as a guest or on mock data from the outside.
    static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [],
                            defaults: UserDefaults = .standard) -> AppDependencies {
        let logger = OSLogLogger()
        let store = makeSessionStore(arguments: arguments, defaults: defaults, logger: logger)
        let identity = SessionIdentityProvider()
        let auth = makeAuthService(arguments: arguments, store: store, logger: logger)
        let repositories = makeRepositories(arguments: arguments,
                                            identity: identity,
                                            tokenProvider: auth.tokenProvider,
                                            logger: logger)
        return AppDependencies(logger: logger,
                               sessionStore: store,
                               authService: auth.service,
                               tokenProvider: auth.tokenProvider,
                               identity: identity,
                               eventRepository: repositories.events,
                               profileRepository: repositories.profile,
                               interactionRecorder: repositories.interactions,
                               locationService: makeLocationService(arguments: arguments, logger: logger),
                               groupRepositories: repositories.groups)
    }

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
                               interactionRecorder: repositories.interactions,
                               locationService: MockLocationService(),
                               groupRepositories: repositories.groups)
    }

    /// Explore starts from the default filter (10 km around the user); a list without a filter button, such as
    /// Home, must never hide a game, so it starts from `.everything`.
    func makeEventListViewModel(scope: EventScope) -> EventListViewModel {
        EventListViewModel(scope: scope,
                           repository: eventRepository,
                           identity: identity,
                           locationService: locationService,
                           changes: eventChanges,
                           errorCenter: errorCenter,
                           recorder: interactionRecorder,
                           logger: logger,
                           initialFilter: scope == .upcoming ? EventFilter() : .everything)
    }

    func makeEventDetailViewModel(for event: SportEvent,
                                  onChange: @escaping @MainActor (SportEvent) -> Void) -> EventDetailViewModel {
        EventDetailViewModel(event: event,
                             repository: eventRepository,
                             identity: identity,
                             errorCenter: errorCenter,
                             recorder: interactionRecorder,
                             logger: logger,
                             onChange: onChange)
    }

    /// `onChange` receives the event as the backend stored it after the host's edit; the detail behind the sheet takes
    /// it through `EventDetailViewModel.accept`.
    func makeEditEventViewModel(for event: SportEvent,
                                onChange: @escaping @MainActor (SportEvent) -> Void) -> EditEventViewModel {
        EditEventViewModel(event: event,
                           repository: eventRepository,
                           errorCenter: errorCenter,
                           logger: logger,
                           onChange: onChange)
    }

    /// `onCreated` receives the event as the backend stored it; the list behind the sheet adds it in place. A sheet
    /// opened from a group's Events segment passes the group as `lockedGroup`, so the game is hosted there.
    func makeCreateEventViewModel(onCreated: @escaping @MainActor (SportEvent) -> Void,
                                  lockedGroup: EventGroupRef? = nil) -> CreateEventViewModel {
        CreateEventViewModel(repository: eventRepository,
                             identity: identity,
                             locationService: locationService,
                             groups: myGroups,
                             errorCenter: errorCenter,
                             logger: logger,
                             lockedGroup: lockedGroup,
                             onCreated: onCreated)
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

    /// The Cognito service doubles as the token provider; the mock has no token to offer. `-mock-user-id` is read
    /// only with the mock: a Cognito user is whoever the pool says.
    private static func makeAuthService(arguments: [String], store: any SessionStore, logger: any Logging) -> Auth {
        if let behavior = mockAuthBehavior(from: arguments) {
            logger.info(.auth, "Launch argument requested mock auth: \(behavior)")
            let userID = AppConfig.LaunchArguments.value(following: AppConfig.LaunchArguments.mockUserID, in: arguments)
            if let userID { logger.info(.auth, "Launch argument set the mock user id to \(userID)") }
            let mock = MockAuthService(behavior: behavior, store: store, userIDOverride: userID)
            return Auth(service: mock, tokenProvider: nil)
        }
        let cognito = CognitoAuthService(client: AmplifyCognitoClient(logger: logger), store: store, logger: logger)
        return Auth(service: cognito, tokenProvider: cognito)
    }

    /// The mock behaviour a launch asks for, `nil` for the real pool. `-mock-auth-fail` and `-mock-auth-confirm` imply
    /// the mock, so the UI tests can add one of them to a launch that already carries `-mock-auth`.
    static func mockAuthBehavior(from arguments: [String]) -> MockAuthBehavior? {
        let flags = AppConfig.LaunchArguments.self
        if arguments.contains(flags.mockAuthFail) { return .fail(.network) }
        if arguments.contains(flags.mockAuthConfirm) {
            return .requireConfirmation(code: AppConfig.Auth.mockConfirmationCode)
        }
        return arguments.contains(flags.mockAuth) ? .succeed : nil
    }

    private static func makeLocationService(arguments: [String], logger: any Logging) -> any LocationService {
        arguments.contains(AppConfig.LaunchArguments.mockLocation)
            ? MockLocationService()
            : CachedLocationService(upstream: CoreLocationService(logger: logger), logger: logger)
    }

    private static func makeRepositories(arguments: [String],
                                         identity: any IdentityProvider,
                                         tokenProvider: (any AuthTokenProvider)?,
                                         logger: any Logging) -> Repositories {
        guard arguments.contains(AppConfig.LaunchArguments.mockEvents) else {
            return .remote(baseURL: apiBaseURL(from: arguments, logger: logger),
                           realtimeEndpoint: realtimeEndpoint(from: arguments, logger: logger),
                           identity: identity,
                           tokenProvider: tokenProvider,
                           logger: logger)
        }
        logger.info(.events, "Launch argument requested mock events")
        let autoReplies = arguments.contains(AppConfig.LaunchArguments.mockChatReplies)
        if autoReplies { logger.info(.chat, "Launch argument requested mock chat replies") }
        let mockPicker = arguments.contains(AppConfig.LaunchArguments.mockAttachmentPicker)
        if mockPicker { logger.info(.chat, "Launch argument requested the mock attachment picker") }
        return .mock(identity: identity, logger: logger, autoReplies: autoReplies, mockPicker: mockPicker)
    }

    /// The `-api-base-url` value when it is a URL with a scheme and a host, otherwise `AppConfig.API.baseURL`.
    static func apiBaseURL(from arguments: [String], logger: any Logging) -> URL {
        guard let url = url(following: AppConfig.LaunchArguments.apiBaseURL, in: arguments, logger: logger) else {
            return AppConfig.API.baseURL
        }
        logger.info(.network, "API base URL overridden: \(url.absoluteString)")
        return url
    }

    /// A value flag's URL when it parses with a scheme and a host; a malformed value is ignored with a warning.
    static func url(following flag: String, in arguments: [String], logger: any Logging) -> URL? {
        guard let value = AppConfig.LaunchArguments.value(following: flag, in: arguments) else { return nil }
        guard let url = URL(string: value), url.scheme != nil, url.host() != nil else {
            logger.warning(.network, "Ignoring \(flag): not a URL with a scheme and a host")
            return nil
        }
        return url
    }
}

/// Who signs the user in, and who hands the API client the token to send: Cognito for both, or the mock and nobody.
private struct Auth {
    let service: any AuthService
    let tokenProvider: (any AuthTokenProvider)?
}

/// The data layer comes as a set: everything talks to the same backend, or everything stays in memory, so a mock run
/// (previews, UI tests, `-mock-events`) never posts a statistic either.
private struct Repositories {
    let events: any EventRepository
    let profile: any ProfileRepository
    let interactions: any InteractionRecorder
    let groups: GroupRepositories

    static func remote(baseURL: URL,
                       realtimeEndpoint: URL?,
                       identity: any IdentityProvider,
                       tokenProvider: (any AuthTokenProvider)?,
                       logger: any Logging) -> Repositories {
        let client = URLSessionAPIClient(baseURL: baseURL, identity: identity, tokenProvider: tokenProvider, logger: logger)
        return Repositories(events: RemoteEventRepository(client: client),
                            profile: RemoteProfileRepository(client: client),
                            interactions: RemoteInteractionRecorder(client: client, identity: identity, logger: logger),
                            groups: .remote(client: client,
                                            realtimeEndpoint: realtimeEndpoint,
                                            identity: identity,
                                            logger: logger))
    }

    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false) -> Repositories {
        Repositories(events: MockEventRepository(identity: identity, logger: logger),
                     profile: MockProfileRepository(logger: logger),
                     interactions: NoOpInteractionRecorder(),
                     groups: .mock(identity: identity, logger: logger, autoReplies: autoReplies, mockPicker: mockPicker))
    }
}
