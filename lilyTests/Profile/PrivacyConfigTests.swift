import Foundation
import Testing
@testable import lily

/// The in-app privacy policy's copy: the sections mirror the served page's shape, every key resolves in all seven
/// languages (a missing catalog entry would silently show English), and the footer names the canonical address. Like
/// the other copy suites, it reads the keys through `AppBranding` on the English test host.
struct PrivacyConfigTests {
    private typealias Privacy = AppBranding.Privacy

    @Test func theSectionsMirrorTheServedPage() {
        let sections = Privacy.sections
        #expect(sections.count == 7)
        #expect(sections.flatMap(\.paragraphs).count == 16)
        #expect(sections.flatMap(\.paragraphs).compactMap(\.lead).count == 8, "the storage section's bold leads")
        let texts = Self.copyTexts
        #expect(Set(texts).count == texts.count, "every key reads its own text")
        for text in texts {
            #expect(!text.isEmpty)
        }
    }

    /// English is the key itself; every other language's compiled table must carry every key. Membership, not a
    /// lookup: a lookup cannot tell a legitimately identical value ("Feedback." stays "Feedback." in Portuguese)
    /// from a missing entry falling back to English.
    @Test func everyKeyResolvesInEveryLanguage() throws {
        let keys = Self.copyTexts
        for language in AppLanguage.allCases where language != .english {
            let folder = try #require(Bundle.main.path(forResource: language.code, ofType: "lproj"),
                                      "\(language.code) folder")
            let path = (folder as NSString).appendingPathComponent("Localizable.strings")
            let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String],
                                     "\(language.code) table")
            for key in keys {
                #expect(table[key]?.isEmpty == false, "\(language.code) lacks \(key.prefix(60))")
            }
        }
    }

    @Test func theFooterNamesTheServedPage() {
        #expect(Privacy.alsoAt.contains(AppConfig.Moderation.privacyURL.absoluteString))
    }

    /// Every key the screen shows, in English (the keys themselves): the date line and each section's texts.
    private static var copyTexts: [String] {
        [Privacy.updated] + Privacy.sections.flatMap { section in
            [section.title] + section.paragraphs.flatMap { [$0.lead, $0.body].compactMap { $0 } }
        }
    }
}
