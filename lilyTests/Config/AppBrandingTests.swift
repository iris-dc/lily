import Testing
@testable import lily

struct AppBrandingTests {
    @Test func signInTitleEmbedsProviderName() {
        #expect(AppBranding.signInButtonTitle(for: "Apple") == "Continue with Apple")
    }

    @Test func brandingStringsAreNotEmpty() {
        #expect(!AppBranding.name.isEmpty)
        #expect(!AppBranding.landingPrimaryAction.isEmpty)
        #expect(!AppBranding.signInAction.isEmpty)
    }
}
