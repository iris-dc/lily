import Testing
@testable import lily

struct AuthUserTests {
    @Test(arguments: [("Jane Doe", "JD"), ("Cher", "C"), ("Ana Maria Silva", "AM"), ("", "")])
    func initialsUseFirstTwoWords(displayName: String, expected: String) {
        let user = AuthUser(id: "u", displayName: displayName, email: nil)
        #expect(user.initials == expected)
    }
}

struct SessionStateTests {
    @Test func onlyGuestAndSignedInAreInsideApp() {
        #expect(!SessionState.loading.isInsideApp)
        #expect(!SessionState.signedOut.isInsideApp)
        #expect(SessionState.guest.isInsideApp)
        #expect(SessionState.signedIn(TestFixtures.user).isInsideApp)
    }

    @Test func userIsOnlyExposedWhenSignedIn() {
        #expect(SessionState.signedIn(TestFixtures.user).user == TestFixtures.user)
        #expect(SessionState.guest.user == nil)
    }
}

struct AuthProviderTests {
    @Test func kindDropsCredentials() {
        #expect(AuthProvider.email(TestFixtures.credentials).kind == .email)
        #expect(AuthProvider.apple.kind == .apple)
        #expect(AuthProvider.google.kind == .google)
    }
}
