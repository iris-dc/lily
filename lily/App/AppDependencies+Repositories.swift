import Foundation

/// Who signs the user in, who hands the API client the token to send, and who reports a refresh token the pool
/// refuses: Cognito for all three, or the mock and nobody.
struct AuthWiring {
    let service: any AuthService
    let tokenProvider: (any AuthTokenProvider)?
    let expiry: (any SessionExpiryReporter)?
}

/// The data layer comes as a set: everything talks to the same backend, or everything stays in memory, so a mock run
/// (previews, UI tests, `-mock-events`) never posts a statistic, registers a device or meets the permission alert.
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
                                            tokenProvider: tokenProvider,
                                            logger: logger),
                            devices: RemoteDeviceRepository(client: client),
                            pushRegistrar: SystemPushRegistrar(logger: logger))
    }

    /// `systemPush` keeps the real permission prompt and token (`-system-push`); the registry stays in memory.
    /// `eventsFailFirst` makes the events mock refuse its first list load (`-mock-events-fail`); `deletedUser` makes
    /// the chat, event, tournament and inbox mocks serve the deleted-flagged fixtures (`-mock-deleted-user`).
    static func mock(identity: any IdentityProvider,
                     logger: any Logging,
                     autoReplies: Bool = false,
                     mockPicker: Bool = false,
                     systemPush: Bool = false,
                     eventsFailFirst: Bool = false,
                     deletedUser: Bool = false) -> Repositories {
        let events = MockEventRepository(identity: identity,
                                         logger: logger,
                                         failsFirstLoad: eventsFailFirst,
                                         deletedHost: deletedUser)
        let profiles = MockProfileRepository(identity: identity, logger: logger)
        let groups = GroupRepositories.mock(identity: identity,
                                            logger: logger,
                                            events: events,
                                            profiles: profiles,
                                            autoReplies: autoReplies,
                                            mockPicker: mockPicker,
                                            deletedFixtures: deletedUser)
        return Repositories(events: events,
                            profile: profiles,
                            feedback: MockFeedbackRepository(logger: logger),
                            interactions: NoOpInteractionRecorder(),
                            groups: groups,
                            devices: MockDeviceRepository(identity: identity, logger: logger),
                            pushRegistrar: systemPush ? SystemPushRegistrar(logger: logger) : MockPushRegistrar(logger: logger))
    }
}

/// The data-layer factories `makeDefault` reads the launch arguments through.
extension AppDependencies {
    /// The Cognito service doubles as the token provider and reports a refresh token the pool refuses; the mock has no
    /// token to offer. `-mock-user-id` is read only with the mock: a Cognito user is whoever the pool says.
    static func makeAuthService(arguments: [String],
                                store: any SessionStore,
                                language: LanguageStore,
                                logger: any Logging) -> AuthWiring {
        if let behavior = mockAuthBehavior(from: arguments) {
            logger.info(.auth, "Launch argument requested mock auth: \(behavior)")
            let userID = AppConfig.LaunchArguments.value(following: AppConfig.LaunchArguments.mockUserID, in: arguments)
            if let userID { logger.info(.auth, "Launch argument set the mock user id to \(userID)") }
            let mock = MockAuthService(behavior: behavior, store: store, userIDOverride: userID)
            return AuthWiring(service: mock, tokenProvider: nil, expiry: nil)
        }
        let cognito = CognitoAuthService(client: AmplifyCognitoClient(logger: logger),
                                         store: store,
                                         languageCode: { language.language.code },
                                         logger: logger)
        return AuthWiring(service: cognito, tokenProvider: cognito, expiry: cognito)
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

    /// The geocoder follows the location service: deterministic under `-mock-location`, Apple's otherwise.
    static func makeGeocoder(arguments: [String], logger: any Logging) -> any GeocodingService {
        arguments.contains(AppConfig.LaunchArguments.mockLocation)
            ? MockGeocodingService()
            : CoreLocationGeocoder(logger: logger)
    }

    static func makeLocationService(arguments: [String], logger: any Logging) -> any LocationService {
        arguments.contains(AppConfig.LaunchArguments.mockLocation)
            ? MockLocationService()
            : CachedLocationService(upstream: CoreLocationService(logger: logger), logger: logger)
    }

    static func makeRepositories(arguments: [String],
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
        let eventsFailFirst = arguments.contains(AppConfig.LaunchArguments.mockEventsFail)
        if eventsFailFirst { logger.info(.events, "Launch argument made the first mock events load fail") }
        let deletedUser = arguments.contains(AppConfig.LaunchArguments.mockDeletedUser)
        if deletedUser { logger.info(.groups, "Launch argument requested the deleted-user fixtures") }
        return .mock(identity: identity,
                     logger: logger,
                     autoReplies: autoReplies,
                     mockPicker: mockPicker,
                     systemPush: systemPush,
                     eventsFailFirst: eventsFailFirst,
                     deletedUser: deletedUser)
    }
}
