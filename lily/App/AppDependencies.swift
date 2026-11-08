import Foundation

/// Composition root. The only place that knows concrete implementations.
final class AppDependencies {
    let logger: any Logging
    let errorCenter: ErrorCenter
    let authService: any AuthService
    /// Source of the Bearer token the API client sends; `nil` while auth is mocked.
    let tokenProvider: (any AuthTokenProvider)?
    let sessionController: SessionController
    /// The user the API client and the event screens act for; answers from `sessionController`.
    let identity: any IdentityProvider
    let eventRepository: any EventRepository
    let profileRepository: any ProfileRepository
    /// The caller's public name, loaded when Profile opens; see `AppDependencies+Profile.swift`.
    let profile: ProfileStore
    /// Where the contact form on Profile sends its messages; see `AppDependencies+Feedback.swift`.
    let feedbackRepository: any FeedbackRepository
    /// Where the event screens report their taps; the root view flushes it when the app goes to the background.
    let interactionRecorder: any InteractionRecorder
    let locationService: any LocationService
    /// Turns a typed place into a spot (and back) for the event forms; see `AppDependencies+Events.swift`.
    let geocoder: any GeocodingService
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
    /// Where the tabs' lists and Mine keep their last answer for the next launch's first frame; see `AppDependencies+Shell.swift`.
    let listSnapshots: any ListSnapshotStore
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
         sessionExpiry: (any SessionExpiryReporter)? = nil,
         identity: SessionIdentityProvider = SessionIdentityProvider(),
         eventRepository: any EventRepository,
         profileRepository: any ProfileRepository,
         feedbackRepository: any FeedbackRepository,
         interactionRecorder: any InteractionRecorder & SessionObserver,
         locationService: any LocationService,
         geocoder: any GeocodingService = MockGeocodingService(),
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
        self.listSnapshots = listSnapshots
        // The stored choices as they are: launch arguments are `makeDefault`'s to read.
        let language = language ?? Self.makeLanguageStore(arguments: [], startsFresh: false, defaults: defaults, logger: logger)
        self.language = language
        self.currency = currency ?? Self.makeCurrencyStore(startsFresh: false, defaults: defaults, logger: logger)
        let errorCenter = errorCenter ?? ErrorCenter(logger: logger)
        self.errorCenter = errorCenter
        self.authService = authService
        self.tokenProvider = tokenProvider
        self.identity = identity
        self.eventRepository = eventRepository
        self.profileRepository = profileRepository
        self.feedbackRepository = feedbackRepository
        self.interactionRecorder = interactionRecorder
        (self.locationService, self.geocoder) = (locationService, geocoder)
        self.sessionController = SessionController(authService: authService,
                                                   sessionStore: sessionStore,
                                                   errorCenter: errorCenter,
                                                   logger: logger)
        // The repositories were built around `identity` before the controller existed; close the loop before the
        // stores are built, since they read the caller for the snapshot they start from.
        identity.session = sessionController
        profile = ProfileStore(repository: profileRepository, identity: identity, snapshots: listSnapshots, logger: logger)
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
                                     errorCenter: errorCenter,
                                     defaults: defaults,
                                     languageCode: { language.language.code },
                                     logger: logger)
        finishWiring(recorder: interactionRecorder, expiry: sessionExpiry)
    }

    /// The start tab follows the cached session, so the shell's first frame is already on it; then everything that
    /// holds state for the signed-in user registers (`recorder` is the parameter's `SessionObserver` face, which the
    /// stored property lacks). The recorder flushes before the session ends, the rest clear after it; the snapshots
    /// last, after the stores and the tabs' lists wrote their cleared lists. Last, a token the pool refuses to refresh
    /// is wired to end the session (`AppDependencies+Session.swift`).
    private func finishWiring(recorder: any SessionObserver, expiry: (any SessionExpiryReporter)?) {
        navigation.selectedTab = AppNavigation.startTab(for: sessionController.state)
        let observers: [any SessionObserver] = groups.sessionObservers
            + [navigation, push.coordinator, recorder, profile, lists, listSnapshots]
        observers.forEach(sessionController.addObserver)
        wireSessionExpiry(expiry)
    }

    /// Production wiring: Cognito through Amplify, whose access token the API client sends, unless a launch argument
    /// asks for the mock. Launch arguments are read in debug builds only (`AppConfig.LaunchArguments.isHonored`); a
    /// release build ignores them, so nobody can start it as a guest or on mock data from the outside. `-reset-session`
    /// is judged once (`startsFresh(arguments:logger:)`) and handed to the store factories. `apply` moves the process-wide
    /// `AppLocale`; it is injectable so a test can build the default root without touching it.
    static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [],
                            defaults: UserDefaults = .standard,
                            apply: @escaping (AppLocale.Context) -> Void = AppLocale.set) -> AppDependencies {
        let logger = OSLogLogger()
        let startsFresh = startsFresh(arguments: arguments, logger: logger)
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
                               sessionExpiry: auth.expiry,
                               identity: identity,
                               eventRepository: repositories.events,
                               profileRepository: repositories.profile,
                               feedbackRepository: repositories.feedback,
                               interactionRecorder: repositories.interactions,
                               locationService: makeLocationService(arguments: arguments, logger: logger),
                               geocoder: makeGeocoder(arguments: arguments, logger: logger),
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
}
