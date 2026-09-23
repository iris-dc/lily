import Foundation
import Testing
@testable import lily

struct AppVersionTests {
    @Test func headerValuePutsTheBuildInParentheses() {
        #expect(AppVersion(marketing: "1.0", build: "42").headerValue == "1.0 (42)")
    }

    @Test func currentReadsBothKeysFromTheBundle() throws {
        let bundle = Bundle.main
        let marketing = try #require(bundle.object(forInfoDictionaryKey: AppConfig.Version.marketingKey) as? String)
        let build = try #require(bundle.object(forInfoDictionaryKey: AppConfig.Version.buildKey) as? String)

        #expect(AppVersion.current(bundle: bundle) == AppVersion(marketing: marketing, build: build))
    }

    /// A bundle without the keys still yields a well-formed header, never a crash.
    @Test func missingKeysFallBackToTheUnknownComponent() {
        let unknown = AppConfig.Version.unknownComponent

        #expect(AppVersion(infoDictionary: [:]) == AppVersion(marketing: unknown, build: unknown))
        #expect(AppVersion(infoDictionary: [AppConfig.Version.buildKey: "42"]).headerValue == "\(unknown) (42)")
    }
}
