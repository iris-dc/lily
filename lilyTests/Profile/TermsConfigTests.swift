import Foundation
import Testing
@testable import lily

/// The in-app terms of use's copy: the sections mirror the served page's shape — minus its version stamp, because
/// agreement is by use and nothing is put to the reader to accept (owner decision 2026-11-08) — and every key
/// resolves in all seven languages (a missing catalog entry would silently show English). Like the other copy
/// suites, it reads the keys through `AppBranding` on the English test host.
struct TermsConfigTests {
    private typealias Terms = AppBranding.Terms

    @Test func theSectionsMirrorTheServedPage() {
        let sections = Terms.sections
        #expect(sections.count == 6)
        #expect(sections.flatMap(\.paragraphs).count == 6, "one paragraph per section, as the page writes them")
        #expect(sections.flatMap(\.paragraphs).compactMap(\.lead).isEmpty, "the terms use no bold leads")
        let texts = Self.copyTexts
        #expect(Set(texts).count == texts.count, "every key reads its own text")
        for text in texts {
            #expect(!text.isEmpty)
        }
    }

    /// Nothing on the screen names a version or asks for acceptance: agreement is by use (owner decision
    /// 2026-11-08), carried by the service section's sentence, and the page's version stamp stays on the page.
    @Test func theTermsReadAsAgreementByUse() {
        let whole = Self.copyTexts.joined(separator: " ").lowercased()
        #expect(!whole.contains("version"))
        #expect(whole.contains("you agree to these terms"), "the agreement-by-use sentence")
    }

    /// English is the key itself; every other language's compiled table must carry every key. Membership, not a
    /// lookup: a lookup cannot tell a legitimately identical value from a missing entry falling back to English.
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

    /// Every key the screen shows, in English (the keys themselves): each section's texts.
    private static var copyTexts: [String] {
        Terms.sections.flatMap { section in
            [section.title] + section.paragraphs.flatMap { [$0.lead, $0.body].compactMap { $0 } }
        }
    }
}
