import Testing
@testable import lily

struct HomeContentTests {
    @Test func guestsAndSignedOutSessionsGetTheSignInPrompt() {
        #expect(HomeContent(for: .guest) == .signInPrompt)
        #expect(HomeContent(for: .signedOut) == .signInPrompt)
    }

    @Test func aSignedInUserGetsTheOverview() {
        #expect(HomeContent(for: .signedIn(TestFixtures.user)) == .overview)
    }
}
