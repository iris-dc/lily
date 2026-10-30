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
    /// `-freeze-aurora`: every aurora stays on its first frame; see `AppDependencies+Knobs.swift`.
    let freezesAurora: Bool
    /// The language the copy is in and the user's choice behind it; the root view re-renders from it.
    let language: LanguageStore
    /// The currency prices are typed in and the price cap is judged in; see `AppDependencies+Currency.swift`.
    let currency: CurrencyStore
    let eventChanges = ChangeTracker()
    /// Groups, chat, inbox and moderation collaborators; see `AppDependencies+Groups.swift`.
    let groups: GroupDependencies
    /// The device registration and the game behind a tapped reminder; see `AppDependencies+Push.swift`.
    let push: PushDependencies
    /// Shell-wide navigation, read by every feature; a session observer, so the next user never lands on the previous
    /// one's screens.
    let navigation = AppNavigation()
    /// The Home and Explore lists, kept for the app's lifetime (`ShellLists`); lazy because the factories read the
    /// stores above, built at the end of `init`, where it registers as a session observer.
    private(set) lazy var lists: ShellLists = makeShellLists()

    init(logger: any Logging,
         sessionStore: any SessionStore,
         authService: any AuthService,
         tokenProvider: (any AuthTokenProvider)? = nil,
         identity: SessionIdentityProvider = SessionIdentityProvider(),
         eventRepository: any EventRepository,
         profileRepository: any ProfileRepository,
         feedbackRepository: any FeedbackRepository,
         interactionRecorder: any InteractionRecorder & SessionObserver,
         locationService: any LocationService,
         groupRepositories: GroupRepositories,
         pushRegistrar: any PushRegistrar,
         deviceRepository: any DeviceRepository,
         language: LanguageStore? = nil,
         currency: CurrencyStore? = nil,
         eventFilterStore: any EventFilterStore = NoOpEventFilterStore(),
         listSnapshots: any ListSnapshotStore = NoOpListSnapshotStore(),
         errorCenter: ErrorCenter? = nil,
         freezesAurora: Bool = false,
         defaults: UserDefaults = .standard) {
        self.logger = logger
        self.eventFilterStore = eventFilterStore
        self.freezesAurora = freezesAurora
        // The stored choices as they are: launch arguments are `makeDefault`'s to read.
        let language = language ?? Self.makeLanguageStore(arguments: [], startsFresh: false, defaults: defaults, logger: logger)
        self.language = language
        self.currency = currency ?? Self.makeCurrencyStore(startsFresh: false, defaults: defaults, logger: logger)
        let errorCenter = errorCenter ?? ErrorCenter(logger: logger)
        self.errorCenter = errorCenter
        self.sessionStore = sessionStore
        self.authService = authService
        self.tokenProvider = tokenProvider
        self.identity = identity
        self.eventRepository = eventRepository
        self.profileRepository = profileRepository
        self.feedbackRepository = feedbackRepository
        self.interactionRecorder = interactionRecorder
        self.locationService = locationService
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   profileRepository: profileRepository,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
        // The repositories were built around `identity` before the controller existed; close the loop before the
        // stores are built, since they read the caller for the snapshot they start from.
        identity.session = sessionController
        self.groups = GroupDependencies(repositories: groupRepositories,
                                        identity: identity,
                                        tokenProvider: tokenProvider,
                                        errorCenter: errorCenter,
                                        logger: logger,
                                        snapshots: listSnapshots)
        self.push = PushDependencies(registrar: pushRegistrar,
                                     devices: deviceRepository,
                                     events: eventRepository,
                                     tournaments: groupRepositories.tournaments,
                                     identity: identity,
                                     navigation: navigation,
                                     groups: groups,
                                     defaults: defaults,
                                     languageCode: { language.language.code },
                                     logger: logger)
        finishWiring(recorder: interactionRecorder)
    }

    /// The start tab follows the cached session, so the shell's first frame is already on it; then everything that
    /// holds state for the signed-in user registers (`recorder` is the parameter's `SessionObserver` face, which the
    /// stored property lacks). The recorder flushes before the session ends, the rest clear after it; the snapshots
    /// last, after the stores and the tabs' lists wrote their cleared lists.
    private func finishWiring(recorder: any SessionObserver) {
        navigation.selectedTab = AppNavigation.startTab(for: sessionController.state)
        let observers: [any SessionObserver] = groups.sessionObservers
            + [navigation, push.coordinator, recorder, lists, listSnapshots]
        observers.forEach(sessionController.addObserver)
    }

    /// Production wiring: Cognito through Amplify, whose access token the API client sends, unless a launch argument
    /// asks for the mock. Launch arguments are read in debug builds only (`AppConfig.LaunchArguments.isHonored`); a
    /// release build ignores them, so nobody can start it as a guest or on mock data from the outside. `-reset-session`
    /// is judged here once and handed to the store factories as `startsFresh`. `apply` moves the process-wide
    /// `AppLocale`; it is injectable so a test can build the default root without touching it.
    static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [],
                            defaults: UserDefaults = .standard,
                            apply: @escaping (AppLocale.Context) -> Void = AppLocale.set) -> AppDependencies {
        let logger = OSLogLogger()
        let startsFresh = arguments.contains(AppConfig.LaunchArguments.resetSession)
        if startsFresh {
            logger.info(.auth, "Launch argument requested a fresh start: stored session, choices, filter and snapshots cleared")
        }
        let language = makeLanguageStore(arguments: arguments,
                                         startsFresh: startsFresh,
                                         defaults: defaults,
                                         logger: logger,
                                         apply: apply)
        let store = makeSessionStore(arguments: arguments, startsFresh: startsFresh, defaults: defaults, logger: logger)
        let identity = SessionIdentityProvider()
        let auth = makeAuthService(arguments: arguments, store: store, language: language, logger: logger)
        let repositories = makeRepositories(arguments: arguments,
                                            identity: identity,
                                            tokenProvider: auth.tokenProvider,
                                            logger: logger)
        let snapshots = makeListSnapshotStore(arguments: arguments, startsFresh: startsFresh, logger: logger)
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
                               currency: makeCurrencyStore(startsFresh: startsFresh, defaults: defaults, logger: logger),
                               eventFilterStore: makeEventFilterStore(startsFresh: startsFresh,
                                                                      defaults: defaults,
                                                                      logger: logger),
                               listSnapshots: snapshots,
                               errorCenter: makeErrorCenter(arguments: arguments, logger: logger),
                               freezesAurora: freezesAurora(arguments: arguments, logger: logger),
                               defaults: defaults)
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
        let termsPending = arguments.contains(AppConfig.LaunchArguments.mockTermsPending)
        if termsPending { logger.info(.groups, "Launch argument made the mock owe the terms") }
        let eventsFailFirst = arguments.contains(AppConfig.LaunchArguments.mockEventsFail)
        if eventsFailFirst { logger.info(.events, "Launch argument made the first mock events load fail") }
        return .mock(identity: identity,
                     logger: logger,
                     autoReplies: autoReplies,
                     mockPicker: mockPicker,
                     systemPush: systemPush,
                     termsPending: termsPending,
                     eventsFailFirst: eventsFailFirst)
    }
}

/// Who signs the user in, and who hands the API client the token to send: Cognito for both, or the mock and nobody.
private struct Auth {
    let service: any AuthService
    let tokenProvider: (any AuthTokenProvider)?
}

/// The data layer comes as a set: everything talks to the same backend, or everything stays in memory, so a mock run
/// (previews, UI tests, `-mock-events`) never posts a statistic, registers a device or meets the permission alert.
/// Internal, not private: `makeMock` (`AppDependencies+Mock.swift`) wires the mock set.
struct Repositories {
    let events: any EventRepository
    let profile: any ProfileRepository
    let feedback: any FeedbackRepository
    let interactions: any InteractionRecorder & SessionObserver
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
    /// `eventsFailFirst` makes the events mock refuse its first list load (`-mock-events-fail`).
    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false,
                     systemPush: Bool = false,
                     termsPending: Bool = false,
                     eventsFailFirst: Bool = false) -> Repositories {
        Repositories(events: MockEventRepository(identity: identity, logger: logger, failsFirstLoad: eventsFailFirst),
                     profile: MockProfileRepository(logger: logger),
                     feedback: MockFeedbackRepository(logger: logger),
                     interactions: NoOpInteractionRecorder(),
                     groups: .mock(identity: identity,
                                   logger: logger,
                                   autoReplies: autoReplies,
                                   mockPicker: mockPicker,
                                   termsPending: termsPending),
                     devices: MockDeviceRepository(identity: identity, logger: logger),
                     pushRegistrar: systemPush ? SystemPushRegistrar(logger: logger) : MockPushRegistrar(logger: logger))
    }
}
