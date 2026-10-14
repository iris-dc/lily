import Testing
@testable import lily

struct CredentialsValidatorTests {
    @Test(arguments: ["a@b.co", "jane.doe@example.com", "  x@y.io  ",
                      String(repeating: "a", count: AppConfig.Auth.emailLocalPartMaxLength) + "@example.com"])
    func acceptsPlausibleEmails(email: String) {
        #expect(CredentialsValidator.isValidEmail(email))
    }

    @Test(arguments: ["", "plain", "@nouser.com", "user@", "user@nodot", "user@.com", "user@dot.",
                      "ja ne@example.com", "jane@exam ple.com", "jane@\nexample.com",
                      "jane@@example.com", "jane@doe@example.com"])
    func rejectsMalformedEmails(email: String) {
        #expect(!CredentialsValidator.isValidEmail(email))
    }

    /// Laurel's `@Email` measures the local part as Java's `String.length()` does, in UTF-16 units: an emoji is two.
    @Test func aLocalPartIsCappedAtSixtyFourUnitsAsTheBackendCountsThem() {
        let cap = AppConfig.Auth.emailLocalPartMaxLength
        #expect(!CredentialsValidator.isValidEmail(String(repeating: "a", count: cap + 1) + "@example.com"))
        #expect(CredentialsValidator.isValidEmail(String(repeating: "a", count: cap - 2) + "😀@example.com"),
                "62 letters and an emoji are 64 units")
        #expect(!CredentialsValidator.isValidEmail(String(repeating: "a", count: cap - 1) + "😀@example.com"),
                "63 letters and an emoji are 64 characters by `count` but 65 units: the backend's measure decides")
    }

    @Test func passwordLengthFollowsConfig() {
        let minimum = AppConfig.Auth.minimumPasswordLength
        #expect(CredentialsValidator.isValidPassword(String(repeating: "x", count: minimum)))
        #expect(!CredentialsValidator.isValidPassword(String(repeating: "x", count: minimum - 1)))
    }
}
