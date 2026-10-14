import Testing
@testable import lily

struct AppBrandingTests {
    @Test func signInTitleEmbedsProviderName() {
        #expect(AppBranding.signInButtonTitle(for: "Apple") == "Continue with Apple")
    }
}
