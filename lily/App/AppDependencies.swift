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
    /// Where the contact form on Profile sends its messages; see `AppDependencies+Feedback.swift`.
    let feedbackRepository: any FeedbackRepository
    /// Where the event screens report their taps; the root view flushes it when the app goes to the background.
    let interactionRecorder: any InteractionRecorder
    let locationService: any LocationService
    /// Explore's filter between launches; see `AppDependencies+Events.swift`.
    let eventFilterStore: any EventFilterStore
    /// The language the copy is in and the user's choice behind it; the root view re-renders from it.
    let language: LanguageStore
    let eventChanges = ChangeTracker()
    /// Groups, chat, inbox and moderation collaborators; see `AppDependencies+Groups.swift`.
    let groups: GroupDependencies
    /// The device registration and the game behind a tapped reminder; see `AppDependencies+Push.swift`.
    let push: PushDependencies
    /// The tournament repository and change counter; see `AppDependencies+Tournaments.swift`.
    let tournaments: TournamentDependencies

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         tokenProvider: (any AuthTokenProvider)? = nil,
         identity: SessionIdentityProvider = SessionIdentityProvider(),
         eventRepository: any EventRepository,
         profileRepository: any ProfileRepository,
         feedbackRepository: any FeedbackRepository,
         interactionRecorder: any InteractionRecorder,
         locationService: any LocationService,
         groupRepositories: GroupRepositories,
         pushRegistrar: any PushRegistrar,
         deviceRepository: any DeviceRepository,
         language: LanguageStore? = nil,
         eventFilterStore: any EventFilterStore = NoOpEventFilterStore(),
         defaults: UserDefaults = .standard) {
        self.logger = logger
        self.eventFilterStore = eventFilterStore
        let language = language ?? LanguageStore(store: UserDefaultsLanguagePreferenceStore(defaults: defaults), logger: logger)
        self.language = language
        self.errorCenter = ErrorCenter(logger: logger)
        self.sessionStore = sessionStore
        self.authService = authService
        self.tokenProvider = tokenProvider
        self.identity = identity
        self.eventRepository = eventRepository
        self.profileRepository = profileRepository
        self.feedbackRepository = feedbackRepository
        self.interactionRecorder = interactionRecorder
        self.locationService = locationService
        self.groups = GroupDependencies(repositories: groupRepositories,
                                        identity: identity,
                                        tokenProvider: tokenProvider,
                                        errorCenter: errorCenter,
                                        logger: logger)
        self.push = PushDependencies(registrar: pushRegistrar,
                                     devices: deviceRepository,
                                     events: eventRepository,
                                     tournaments: groupRepositories.tournaments,
                                     identity: identity,
                                     groups: groups,
                                     defaults: defaults,
                                     languageCode: { language.language.code },
                                     logger: logger)
        self.tournaments = TournamentDependencies(repository: groupRepositories.tournaments,
                                                  tournamentChanges: groups.tournamentChanges)
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   profileRepository: profileRepository,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
        // The repositories were built around `identity` before the controller existed; close the loop.
        identity.session = sessionController
        groups.sessionObservers.forEach(sessionController.addObserver)
        sessionController.addObserver(push.coordinator)
    }

    /// Production wiring: Cognito through Amplify, whose access token the API client sends, unless a launch argument
    /// asks for the mock. Launch arguments are read in debug builds only (`AppConfig.LaunchArguments.isHonored`); a
    /// release build ignores them, so nobody can start it as a guest or on mock data from the outside.
    static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [],
                            defaults: UserDefaults = .standard) -> AppDependencies {
        let logger = OSLogLogger()
        let language = makeLanguageStore(arguments: arguments, defaults: defaults, logger: logger)
        let store = makeSessionStore(arguments: arguments, defaults: defaults, logger: logger)
        let identity = SessionIdentityProvider()
        let auth = makeAuthService(arguments: arguments, store: store, language: language, logger: logger)
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
                               feedbackRepository: repositories.feedback,
                               interactionRecorder: repositories.interactions,
                               locationService: makeLocationService(arguments: arguments, logger: logger),
                               groupRepositories: repositories.groups,
                               pushRegistrar: repositories.pushRegistrar,
                               deviceRepository: repositories.devices,
                               language: language,
                               eventFilterStore: makeEventFilterStore(arguments: arguments, defaults: defaults, logger: logger),
                               defaults: defaults)
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
                               feedbackRepository: repositories.feedback,
                               interactionRecorder: repositories.interactions,
                               locationService: MockLocationService(),
                               groupRepositories: repositories.groups,
                               pushRegistrar: repositories.pushRegistrar,
                               deviceRepository: repositories.devices,
                               defaults: defaults)
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
    private static func makeAuthService(arguments: [String],
                                        store: any SessionStore,
                                        language: LanguageStore,
                                        logger: any Logging) -> Auth {
        if let behavior = mockAuthBehavior(from: arguments) {
            logger.info(.auth, "Launch argument requested mock auth: \(behavior)")
            let userID = AppConfig.LaunchArguments.value(following: AppConfig.LaunchArguments.mockUserID, in: arguments)
            if let userID { logger.info(.auth, "Launch argument set the mock user id to \(userID)") }
            let mock = MockAuthService(behavior: behavior, store: store, userIDOverride: userID)
            return Auth(service: mock, tokenProvider: nil)
        }
        let cognito = CognitoAuthService(client: AmplifyCognitoClient(logger: logger),
                                         store: store,
                                         languageCode: { language.language.code },
                                         logger: logger)
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
        let systemPush = arguments.contains(AppConfig.LaunchArguments.systemPush)
        if systemPush { logger.info(.push, "Launch argument kept the system push registrar") }
        return .mock(identity: identity,
                     logger: logger,
                     autoReplies: autoReplies,
                     mockPicker: mockPicker,
                     systemPush: systemPush)
    }
}

/// Who signs the user in, and who hands the API client the token to send: Cognito for both, or the mock and nobody.
private struct Auth {
    let service: any AuthService
    let tokenProvider: (any AuthTokenProvider)?
}

/// The data layer comes as a set: everything talks to the same backend, or everything stays in memory, so a mock run
/// (previews, UI tests, `-mock-events`) never posts a statistic, registers a device or meets the permission alert.
private struct Repositories {
    let events: any EventRepository
    let profile: any ProfileRepository
    let feedback: any FeedbackRepository
    let interactions: any InteractionRecorder
    let groups: GroupRepositories
    let devices: any DeviceRepository
    let pushRegistrar: any PushRegistrar

    static func remote(baseURL: URL,
                       realtimeEndpoint: URL?,
                       identity: any IdentityProvider,
                       tokenProvider: (any AuthTokenProvider)?,
                       logger: any Logging) -> Repositories {
        let client = URLSessionAPIClient(baseURL: baseURL, identity: identity, tokenProvider: tokenProvider, logger: logger)
        return Repositories(events: RemoteEventRepository(client: client),
                            profile: RemoteProfileRepository(client: client),
                            feedback: RemoteFeedbackRepository(client: client),
                            interactions: RemoteInteractionRecorder(client: client, identity: identity, logger: logger),
                            groups: .remote(client: client,
                                            realtimeEndpoint: realtimeEndpoint,
                                            identity: identity,
                                            logger: logger),
                            devices: RemoteDeviceRepository(client: client),
                            pushRegistrar: SystemPushRegistrar(logger: logger))
    }

    /// `systemPush` keeps the real permission prompt and token (`-system-push`); the registry stays in memory.
    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false,
                     systemPush: Bool = false) -> Repositories {
        Repositories(events: MockEventRepository(identity: identity, logger: logger),
                     profile: MockProfileRepository(logger: logger),
                     feedback: MockFeedbackRepository(logger: logger),
                     interactions: NoOpInteractionRecorder(),
                     groups: .mock(identity: identity, logger: logger, autoReplies: autoReplies, mockPicker: mockPicker),
                     devices: MockDeviceRepository(identity: identity, logger: logger),
                     pushRegistrar: systemPush ? SystemPushRegistrar(logger: logger) : MockPushRegistrar(logger: logger))
    }
}
