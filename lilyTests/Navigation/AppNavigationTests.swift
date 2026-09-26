import SwiftUI
import Testing
@testable import lily

@MainActor
struct AppNavigationTests {
    @Test func startsOnExploreWithAnEmptyGroupsStack() {
        let navigation = AppNavigation()
        #expect(navigation.selectedTab == .explore)
        #expect(navigation.groupsPath.isEmpty)
    }

    /// A push from a root sheet or the badge must show the Groups tab too, or the pushed screen stays out of sight.
    @Test func openingInGroupsSelectsTheTabAndPushes() {
        let navigation = AppNavigation()

        navigation.openInGroups("destination")

        #expect(navigation.selectedTab == .groups)
        #expect(navigation.groupsPath.count == 1)
    }

    @Test func poppingToRootEmptiesTheGroupsStack() {
        let navigation = AppNavigation()
        navigation.openInGroups("one")
        navigation.openInGroups("two")

        navigation.popGroupsToRoot()

        #expect(navigation.groupsPath.isEmpty)
        #expect(navigation.selectedTab == .groups)
    }

    @Test func openingAGroupOrItsChatSelectsTheTabAndPushesOne() {
        let navigation = AppNavigation()

        navigation.open(group: .fixture(id: "a"))
        navigation.open(chat: .fixture(id: "b"))

        #expect(navigation.selectedTab == .groups)
        #expect(navigation.groupsPath.count == 2)
    }

    @Test func tabsAreInBarOrder() {
        #expect(AppTab.allCases == [.explore, .myEvents, .groups, .profile])
    }

    /// The pushed screens were the previous user's; the next one starts where a guest does.
    @Test func signOutResetsTheTabAndTheGroupsStack() {
        let navigation = AppNavigation()
        navigation.open(chat: .fixture(id: "a"))

        navigation.sessionDidEnd()

        #expect(navigation.selectedTab == .explore)
        #expect(navigation.groupsPath.isEmpty)
    }

    /// Through the composition root: a sign-out must reach the navigation like every other per-user state.
    @Test func signOutResetsTheShellThroughTheSessionController() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        dependencies.navigation.open(chat: .fixture(id: MockGroupFixtures.kickersID))
        #expect(dependencies.navigation.selectedTab == .groups && dependencies.navigation.groupsPath.count == 1)

        await dependencies.sessionController.signOut()

        #expect(dependencies.navigation.selectedTab == .explore && dependencies.navigation.groupsPath.isEmpty)
    }
}
