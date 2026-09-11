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

    /// My Events has no filter button, so it must never hide a game; Explore starts from the default filter.
    @Test func myEventsStartsFromEverythingAndExploreFromTheDefaults() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.makeEventListViewModel(scope: .joined).filter == .everything)
        #expect(dependencies.makeEventListViewModel(scope: .upcoming).filter == EventFilter())
    }
}
