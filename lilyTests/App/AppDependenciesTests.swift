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
        let store = UserDefaultsSessionStore(defaults: defaults)
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession], defaults: defaults)

        #expect(store.load() == nil)
    }

    @Test func defaultLaunchKeepsStoredSession() {
        let defaults = makeDefaults()
        let store = UserDefaultsSessionStore(defaults: defaults)
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [], defaults: defaults)

        #expect(store.load() == .guest)
    }

    @Test func startAsGuestLaunchArgumentStoresGuestChoice() {
        let defaults = makeDefaults()
        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                    AppConfig.LaunchArguments.startAsGuest],
                                        defaults: defaults)
        #expect(UserDefaultsSessionStore(defaults: defaults).load() == .guest)
    }

    @Test func mockLocationLaunchArgumentSelectsMockService() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockLocation], defaults: makeDefaults())
        #expect(mocked.locationService is MockLocationService)
        let real = AppDependencies.makeDefault(arguments: [], defaults: makeDefaults())
        #expect(real.locationService is CoreLocationService)
    }
}
