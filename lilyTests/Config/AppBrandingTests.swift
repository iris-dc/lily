import Testing
@testable import lily

struct AppBrandingTests {
    @Test func signInTitleEmbedsProviderName() {
        #expect(AppBranding.signInButtonTitle(for: "Apple") == "Continue with Apple")
    }

    @Test func brandingStringsAreNotEmpty() {
        #expect(!AppBranding.name.isEmpty)
        #expect(AppBranding.headline.count >= 2)
        #expect(AppBranding.headline.allSatisfy { !$0.isEmpty })
        #expect(!AppBranding.landingPrimaryAction.isEmpty)
    }
}
