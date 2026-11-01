import Testing
@testable import lily

/// The composition root reads the cached session before any frame: the state and the start tab follow it.
@MainActor
struct AppDependenciesSessionTests {
    private let arguments = [AppConfig.LaunchArguments.mockEvents, AppConfig.LaunchArguments.mockAuth]

    @Test func aCachedUserStartsSignedInOnHome() {
        let defaults = makeTestDefaults()
        UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger()).save(.signedIn(TestFixtures.session))

        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: defaults)

        #expect(dependencies.sessionController.state == .signedIn(TestFixtures.user))
        #expect(dependencies.navigation.selectedTab == .home)
    }

    @Test func aGuestAndANewcomerStartOnExplore() {
        let guestDefaults = makeTestDefaults()
        UserDefaultsSessionStore(defaults: guestDefaults, logger: SpyLogger()).save(.guest)
        let guest = AppDependencies.makeDefault(arguments: arguments, defaults: guestDefaults)
        let newcomer = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())

        #expect(guest.sessionController.state == .guest && guest.navigation.selectedTab == .explore)
        #expect(newcomer.sessionController.state == .signedOut && newcomer.navigation.selectedTab == .explore)
    }

    /// The root's closure end to end: the Cognito service's report ends the session, the navigation resets and the
    /// popup says why. Over the mock data layer and in-memory stores, so nothing reaches Amplify or the Caches folder.
    @Test func aDeadRefreshTokenMidSessionSignsTheUserOutThroughTheRoot() async {
        let client = FakeCognitoClient()
        client.signedIn = true
        client.tokenResult = .failure(.sessionExpired)
        let store = InMemorySessionStore()
        store.stored = .signedIn(TestFixtures.session)
        let logger = SpyLogger()
        let cognito = CognitoAuthService(client: client, store: store, languageCode: { "en" }, logger: logger)
        let identity = SessionIdentityProvider()
        let repositories = Repositories.mock(identity: identity, logger: logger)
        let dependencies = AppDependencies(logger: logger,
                                           sessionStore: store,
                                           authService: cognito,
                                           tokenProvider: cognito,
                                           sessionExpiry: cognito,
                                           identity: identity,
                                           eventRepository: repositories.events,
                                           profileRepository: repositories.profile,
                                           feedbackRepository: repositories.feedback,
                                           interactionRecorder: repositories.interactions,
                                           locationService: MockLocationService(),
                                           groupRepositories: repositories.groups,
                                           pushRegistrar: repositories.pushRegistrar,
                                           deviceRepository: repositories.devices,
                                           listSnapshots: InMemoryListSnapshotStore(),
                                           defaults: makeTestDefaults())
        #expect(dependencies.sessionController.state == .signedIn(TestFixtures.user))
        #expect(dependencies.navigation.selectedTab == .home)
        let generation = dependencies.navigation.shellGeneration

        #expect(await dependencies.tokenProvider?.accessToken() == nil)
        await settle(until: { dependencies.sessionController.state == .signedOut && client.signOutCount == 1 })

        #expect(store.stored == nil)
        #expect(dependencies.errorCenter.current?.error == .sessionExpired)
        #expect(dependencies.navigation.selectedTab == .explore)
        #expect(dependencies.navigation.shellGeneration == generation + 1)
    }
}
