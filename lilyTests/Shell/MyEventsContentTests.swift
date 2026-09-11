import Testing
@testable import lily

struct MyEventsContentTests {
    /// Guests have joined nothing and hold no token, so the tab must not ask for the `.joined` slice.
    @Test func guestsAreAskedToSignInInsteadOfLoadingJoinedEvents() {
        #expect(MyEventsContent(for: .guest) == .signInPrompt)
        #expect(MyEventsContent(for: .signedOut) == .signInPrompt)
        #expect(MyEventsContent(for: .loading) == .signInPrompt)
    }

    @Test func signedInUsersSeeTheirJoinedEvents() {
        #expect(MyEventsContent(for: .signedIn(TestFixtures.user)) == .joinedEvents)
    }
}
