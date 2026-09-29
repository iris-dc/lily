import SwiftUI
import Testing
@testable import lily

@MainActor
struct AppNavigationTests {
    @Test func startsOnExploreWithEmptyStacks() {
        let navigation = AppNavigation()
        #expect(navigation.selectedTab == .explore)
        #expect(navigation.homePath.isEmpty && navigation.chatPath.isEmpty)
    }

    /// A push from a group detail or an accepted invite must show the tab too, or the pushed screen stays out of sight.
    @Test func openingInHomeOrInChatSelectsTheTabAndPushes() {
        let navigation = AppNavigation()

        navigation.openInHome("destination")
        #expect(navigation.selectedTab == .home && navigation.homePath.count == 1)

        navigation.openInChat("destination")
        #expect(navigation.selectedTab == .chat && navigation.chatPath.count == 1 && navigation.homePath.count == 1)
    }

    @Test func poppingToRootEmptiesOneStackAndLeavesTheOther() {
        let navigation = AppNavigation()
        navigation.openInHome("one")
        navigation.openInHome("two")
        navigation.openInChat("three")

        navigation.popHomeToRoot()
        #expect(navigation.homePath.isEmpty && navigation.chatPath.count == 1)

        navigation.popChatToRoot()
        #expect(navigation.chatPath.isEmpty && navigation.selectedTab == .chat)
    }

    /// A group opens its detail on Home; its chat lives on the Chats tab (debug builds have chat on).
    @Test func aGroupOpensOnHomeAndItsChatOnTheChatsStack() {
        let navigation = AppNavigation()

        navigation.open(group: .fixture(id: "a"))
        #expect(navigation.selectedTab == .home && navigation.homePath.count == 1)

        navigation.open(chat: .fixture(id: "b"))
        #expect(navigation.selectedTab == .chat && navigation.chatPath.count == 1 && navigation.homePath.count == 1)
    }

    @Test func tabsAreInBarOrder() {
        #expect(AppTab.allCases == [.home, .explore, .chat, .profile])
    }

    /// A restored user lands on their groups and games; a guest (or nobody yet) on the games the landing promised.
    @Test func aLaunchStartsSignedInUsersOnHomeAndEveryoneElseOnExplore() {
        #expect(AppNavigation.startTab(for: .signedIn(TestFixtures.user)) == .home)
        #expect(AppNavigation.startTab(for: .guest) == .explore)
        #expect(AppNavigation.startTab(for: .signedOut) == .explore)
        #expect(AppNavigation.startTab(for: .loading) == .explore)
    }

    /// The pushed screens were the previous user's; the next one starts where a guest does.
    @Test func signOutResetsTheTabAndBothStacks() {
        let navigation = AppNavigation()
        navigation.open(group: .fixture(id: "a"))
        navigation.open(chat: .fixture(id: "a"))

        navigation.sessionDidEnd()

        #expect(navigation.selectedTab == .explore)
        #expect(navigation.homePath.isEmpty && navigation.chatPath.isEmpty)
    }

    /// Through the composition root: a sign-out must reach the navigation like every other per-user state.
    @Test func signOutResetsTheShellThroughTheSessionController() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        dependencies.navigation.open(chat: .fixture(id: MockGroupFixtures.kickersID))
        #expect(dependencies.navigation.selectedTab == .chat && dependencies.navigation.chatPath.count == 1)

        await dependencies.sessionController.signOut()

        #expect(dependencies.navigation.selectedTab == .explore && dependencies.navigation.chatPath.isEmpty)
    }
}
