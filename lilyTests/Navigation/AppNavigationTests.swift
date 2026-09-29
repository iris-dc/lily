import SwiftUI
import Testing
@testable import lily

@MainActor
struct AppNavigationTests {
    @Test func startsOnExploreWithAnEmptyHomeStack() {
        let navigation = AppNavigation()
        #expect(navigation.selectedTab == .explore)
        #expect(navigation.homePath.isEmpty)
    }

    /// A push from a root sheet or a group detail must show the Home tab too, or the pushed screen stays out of sight.
    @Test func openingInHomeSelectsTheTabAndPushes() {
        let navigation = AppNavigation()

        navigation.openInHome("destination")

        #expect(navigation.selectedTab == .home)
        #expect(navigation.homePath.count == 1)
    }

    @Test func poppingToRootEmptiesTheHomeStack() {
        let navigation = AppNavigation()
        navigation.openInHome("one")
        navigation.openInHome("two")

        navigation.popHomeToRoot()

        #expect(navigation.homePath.isEmpty)
        #expect(navigation.selectedTab == .home)
    }

    @Test func openingAGroupOrItsChatSelectsTheTabAndPushesOne() {
        let navigation = AppNavigation()

        navigation.open(group: .fixture(id: "a"))
        navigation.open(chat: .fixture(id: "b"))

        #expect(navigation.selectedTab == .home)
        #expect(navigation.homePath.count == 2)
    }

    @Test func tabsAreInBarOrder() {
        #expect(AppTab.allCases == [.home, .explore, .profile])
    }

    /// A restored user lands on their groups and games; a guest (or nobody yet) on the games the landing promised.
    @Test func aLaunchStartsSignedInUsersOnHomeAndEveryoneElseOnExplore() {
        #expect(AppNavigation.startTab(for: .signedIn(TestFixtures.user)) == .home)
        #expect(AppNavigation.startTab(for: .guest) == .explore)
        #expect(AppNavigation.startTab(for: .signedOut) == .explore)
        #expect(AppNavigation.startTab(for: .loading) == .explore)
    }

    /// The pushed screens were the previous user's; the next one starts where a guest does.
    @Test func signOutResetsTheTabAndTheHomeStack() {
        let navigation = AppNavigation()
        navigation.open(chat: .fixture(id: "a"))

        navigation.sessionDidEnd()

        #expect(navigation.selectedTab == .explore)
        #expect(navigation.homePath.isEmpty)
    }

    /// Through the composition root: a sign-out must reach the navigation like every other per-user state.
    @Test func signOutResetsTheShellThroughTheSessionController() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        dependencies.navigation.open(chat: .fixture(id: MockGroupFixtures.kickersID))
        #expect(dependencies.navigation.selectedTab == .home && dependencies.navigation.homePath.count == 1)

        await dependencies.sessionController.signOut()

        #expect(dependencies.navigation.selectedTab == .explore && dependencies.navigation.homePath.isEmpty)
    }
}
