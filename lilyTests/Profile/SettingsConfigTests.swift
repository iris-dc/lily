import Testing
import UIKit
@testable import lily

/// Every SF Symbol the Settings rows name exists, and the screen's copy keys resolve to distinct texts: a misspelt
/// symbol name or a key typo would otherwise only show at runtime.
struct SettingsConfigTests {
    private typealias Symbols = DesignTokens.Symbols

    @Test func everySettingsSymbolExists() {
        for name in [Symbols.settings, Symbols.privacy, Symbols.terms] {
            #expect(UIImage(systemName: name) != nil, "no SF Symbol named \(name)")
        }
    }

    @Test func theSettingsCopyKeysResolve() {
        let copy = [AppBranding.Settings.title, AppBranding.Settings.rowSubtitle,
                    AppBranding.Settings.privacySubtitle, AppBranding.Settings.termsSubtitle]
        #expect(Set(copy).count == copy.count, "every key reads its own text")
        for text in copy {
            #expect(!text.isEmpty)
        }
    }
}
