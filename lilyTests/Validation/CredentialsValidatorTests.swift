import Testing
@testable import lily

struct CredentialsValidatorTests {
    @Test(arguments: ["a@b.co", "jane.doe@example.com", "  x@y.io  "])
    func acceptsPlausibleEmails(email: String) {
        #expect(CredentialsValidator.isValidEmail(email))
    }

    @Test(arguments: ["", "plain", "@nouser.com", "user@", "user@nodot", "user@.com", "user@dot."])
    func rejectsMalformedEmails(email: String) {
        #expect(!CredentialsValidator.isValidEmail(email))
    }

    @Test func passwordLengthFollowsConfig() {
        let minimum = AppConfig.Auth.minimumPasswordLength
        #expect(CredentialsValidator.isValidPassword(String(repeating: "x", count: minimum)))
        #expect(!CredentialsValidator.isValidPassword(String(repeating: "x", count: minimum - 1)))
    }
}
