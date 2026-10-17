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
}
