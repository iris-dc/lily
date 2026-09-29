import Testing
@testable import lily

struct AuthUserTests {
    @Test(arguments: [("Jane Doe", "JD"), ("Cher", "C"), ("Ana Maria Silva", "AM"), ("", "")])
    func initialsUseFirstTwoWords(displayName: String, expected: String) {
        let user = AuthUser(id: "u", displayName: displayName, email: nil)
        #expect(user.initials == expected)
    }

    @Test(arguments: [("jane.doe@example.com", "Jane Doe"), ("pat_lee@x.co", "Pat Lee"), ("cher@x.co", "Cher"),
                      ("nomail", "Nomail")])
    func displayNameComesFromTheLocalPart(email: String, expected: String) {
        #expect(AuthUser.displayName(fromEmail: email) == expected)
    }
}

struct SessionStateTests {
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
