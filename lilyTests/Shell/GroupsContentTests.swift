import Testing
@testable import lily

struct GroupsContentTests {
    /// Guests hold no token, so Mine must not ask for `scope=mine`; Discover stays open to them either way.
    @Test func guestsAreAskedToSignInUnderMine() {
        #expect(GroupsContent(for: .guest) == .signInPrompt)
        #expect(GroupsContent(for: .signedOut) == .signInPrompt)
        #expect(GroupsContent(for: .loading) == .signInPrompt)
    }

    @Test func signedInUsersSeeTheirGroups() {
        #expect(GroupsContent(for: .signedIn(TestFixtures.user)) == .myGroups)
    }

    /// A guest lands on Discover, where there is something to see; a user lands on their own groups.
    @Test func guestsStartOnDiscoverAndUsersOnMine() {
        #expect(GroupsContent.signInPrompt.initialScope == .discover)
        #expect(GroupsContent.myGroups.initialScope == .mine)
    }
}
