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

    @Test func makeMockNeverTouchesTheNetwork() {
        let mock = AppDependencies.makeMock()
        #expect(mock.eventRepository is MockEventRepository)
        #expect(mock.profileRepository is MockProfileRepository)
    }

    /// The API client and the event screens ask `identity`; it must follow the session without extra wiring.
    @Test func identityFollowsTheSession() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeDefaults())
        #expect(dependencies.identity.currentUserID == nil)

        await dependencies.sessionController.signIn(with: .apple)
        #expect(dependencies.identity.currentUserID == MockUsers.user(for: .apple).id)

        await dependencies.sessionController.signOut()
        #expect(dependencies.identity.currentUserID == nil)
    }
}
