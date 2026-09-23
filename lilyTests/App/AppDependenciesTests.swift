import Foundation
import Testing
@testable import lily

@MainActor
struct AppDependenciesTests {
    /// Each test gets its own suite so parallel tests never share state.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "lily.tests.dependencies.\(UUID().uuidString)")!
    }

    @Test func resetSessionLaunchArgumentClearsStoredSession() {
        let defaults = makeDefaults()
        let store = UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger())
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession], defaults: defaults)

        #expect(store.load() == nil)
    }

    @Test func defaultLaunchKeepsStoredSession() {
        let defaults = makeDefaults()
        let store = UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger())
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [], defaults: defaults)

        #expect(store.load() == .guest)
    }

    @Test func startAsGuestLaunchArgumentStoresGuestChoice() {
        let defaults = makeDefaults()
        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                    AppConfig.LaunchArguments.startAsGuest],
                                        defaults: defaults)
        #expect(UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger()).load() == .guest)
    }

    @Test func mockAuthFailLaunchArgumentMakesSignInFailWithAPopup() async {
        let failing = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                              AppConfig.LaunchArguments.mockAuthFail],
                                                  defaults: makeDefaults())
        let signedIn = await failing.sessionController.signIn(with: .apple)
        #expect(!signedIn)
        #expect(failing.errorCenter.current != nil)
        #expect(failing.sessionController.state.user == nil)
    }

    /// Nothing here touches Amplify: the client configures it on its first call, and none is made.
    @Test func defaultAuthIsCognitoAndFeedsTheTokenProvider() {
        let dependencies = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())

        #expect(dependencies.authService is CognitoAuthService)
        #expect(dependencies.tokenProvider is CognitoAuthService)
    }

    @Test func mockAuthLaunchArgumentSelectsTheMockWithoutATokenProvider() {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockAuth], defaults: makeDefaults())

        #expect(dependencies.authService is MockAuthService)
        #expect(dependencies.tokenProvider == nil)
    }

    @Test func mockAuthConfirmLaunchArgumentAsksForTheMockCode() async {
        let arguments = [AppConfig.LaunchArguments.resetSession, AppConfig.LaunchArguments.mockAuth,
                         AppConfig.LaunchArguments.mockAuthConfirm, AppConfig.LaunchArguments.mockEvents]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeDefaults())
        let controller = dependencies.sessionController

        #expect(await controller.signUp(email: "a@b.co", password: "long-enough") == .confirmationRequired)
        #expect(await controller.confirmSignUp(email: "a@b.co", code: "000000", password: "long-enough") == false)
        #expect(dependencies.errorCenter.current?.error == .invalidConfirmationCode)
        let code = AppConfig.Auth.mockConfirmationCode
        #expect(await controller.confirmSignUp(email: "a@b.co", code: code, password: "long-enough"))
        #expect(controller.state.user != nil)
    }

    /// Fail beats confirm beats plain, so a test can add a flag to the default `-mock-auth` launch.
    @Test func mockAuthBehaviorFollowsTheLaunchArguments() {
        let flags = AppConfig.LaunchArguments.self
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockEvents]) == nil)
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuth]) == .succeed)
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuth, flags.mockAuthConfirm])
                == .requireConfirmation(code: AppConfig.Auth.mockConfirmationCode))
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuthConfirm, flags.mockAuthFail]) == .fail(.network))
    }

    @Test func mockLocationLaunchArgumentSelectsMockService() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockLocation], defaults: makeDefaults())
        #expect(mocked.locationService is MockLocationService)
        let real = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())
        #expect((real.locationService as? CachedLocationService)?.upstream is CoreLocationService)
    }

    @Test func mockEventsLaunchArgumentSelectsInMemoryRepositories() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeDefaults())
        #expect(mocked.eventRepository is MockEventRepository)
        #expect(mocked.profileRepository is MockProfileRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())
        #expect(remote.eventRepository is RemoteEventRepository)
        #expect(remote.profileRepository is RemoteProfileRepository)
    }

    /// A mock run (UI tests, previews, `-mock-events`) must never post a statistic; the default wiring posts to the
    /// same backend the repositories use.
    @Test func mockEventsSelectTheNoOpRecorderAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeDefaults())
        #expect(mocked.interactionRecorder is NoOpInteractionRecorder)
        #expect(AppDependencies.makeMock().interactionRecorder is NoOpInteractionRecorder)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())
        #expect(remote.interactionRecorder is RemoteInteractionRecorder)
    }

    @Test func apiBaseURLLaunchArgumentOverridesTheDefault() {
        let logger = SpyLogger()
        let arguments = [AppConfig.LaunchArguments.apiBaseURL, "http://mac.local:8080", AppConfig.LaunchArguments.mockLocation]

        let url = AppDependencies.apiBaseURL(from: arguments, logger: logger)

        #expect(url == URL(string: "http://mac.local:8080"))
        #expect(logger.messages(in: .network, at: .info) == ["API base URL overridden: http://mac.local:8080"])
    }

    @Test func apiBaseURLLaunchArgumentWithoutSchemeOrHostIsIgnoredWithAWarning() {
        let logger = SpyLogger()

        let url = AppDependencies.apiBaseURL(from: [AppConfig.LaunchArguments.apiBaseURL, "mac.local:8080"], logger: logger)

        #expect(url == AppConfig.API.baseURL)
        #expect(logger.messages(in: .network, at: .warning).count == 1)
        #expect(logger.messages(in: .network, at: .info).isEmpty)
    }

    @Test func apiBaseURLIsTheConfiguredOneWithoutTheArgument() {
        let logger = SpyLogger()

        let url = AppDependencies.apiBaseURL(from: [AppConfig.LaunchArguments.mockLocation], logger: logger)

        #expect(url == AppConfig.API.baseURL)
        #expect(logger.entries.isEmpty)
    }

    @Test func makeMockNeverTouchesTheNetwork() {
        let mock = AppDependencies.makeMock()
        #expect(mock.eventRepository is MockEventRepository)
        #expect(mock.profileRepository is MockProfileRepository)
    }

    /// The API client and the event screens ask `identity`; it must follow the session without extra wiring.
    @Test func identityFollowsTheSession() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeDefaults())
        #expect(dependencies.identity.currentUserID == nil)

        await dependencies.sessionController.signIn(with: .apple)
        #expect(dependencies.identity.currentUserID == MockUsers.user(for: .apple).id)

        await dependencies.sessionController.signOut()
        #expect(dependencies.identity.currentUserID == nil)
    }

    /// My Events has no filter button, so it must never hide a game; Explore starts from the default filter.
    @Test func myEventsStartsFromEverythingAndExploreFromTheDefaults() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.makeEventListViewModel(scope: .joined).filter == .everything)
        #expect(dependencies.makeEventListViewModel(scope: .upcoming).filter == EventFilter())
    }
}
