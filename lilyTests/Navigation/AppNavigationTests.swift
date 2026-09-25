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
}
