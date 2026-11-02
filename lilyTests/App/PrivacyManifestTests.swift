import Foundation
import Testing
@testable import lily

/// The privacy manifest as the build shipped it (the tests run hosted in lily.app): at the bundle root, where App Store
/// Connect reads it, declaring exactly the required-reason API categories the app calls and no tracking.
struct PrivacyManifestTests {
    private static let name = "PrivacyInfo"
    private static let fileExtension = "xcprivacy"

    @Test func theManifestShipsAtTheBundleRootWithTheTwoAPIsTheAppCalls() throws {
        let url = try #require(Bundle.main.url(forResource: Self.name, withExtension: Self.fileExtension))
        #expect(url.deletingLastPathComponent().standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL)

        let manifest = try Self.manifest()
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        var reasonsByCategory: [String: [String]] = [:]
        for api in apis {
            let category = try #require(api["NSPrivacyAccessedAPIType"] as? String)
            reasonsByCategory[category] = try #require(api["NSPrivacyAccessedAPITypeReasons"] as? [String])
        }
        #expect(reasonsByCategory == ["NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
                                      "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"]])
    }

    @Test func theManifestDeclaresNoTrackingAndNoDomains() throws {
        let manifest = try Self.manifest()
        let domains = try #require(manifest["NSPrivacyTrackingDomains"] as? [String])
        let collected = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [Any])
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect(domains.isEmpty)
        #expect(collected.isEmpty)
    }

    private static func manifest() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: fileExtension))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: Any])
    }
}
