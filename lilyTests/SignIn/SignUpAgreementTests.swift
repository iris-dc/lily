import Foundation
import Testing
@testable import lily

/// The sign-up agreement footnote's copy (owner decision 2026-11-08: agreement is by use, carried by this sentence):
/// the sentence embeds the two document names wherever a language puts them, and the key resolves in all seven
/// languages (a missing entry would silently show English).
struct SignUpAgreementTests {
    /// The compiled key: English is the key itself, with one `%@` per interpolated document name.
    private static let key = "By creating an account you agree to the %@ and %@."

    @Test func theSentenceEmbedsBothDocumentNames() {
        let sentence = AppBranding.signUpAgreement(terms: "<T>", privacy: "<P>")
        #expect(sentence.contains("<T>") && sentence.contains("<P>"))
        #expect(sentence.contains("By creating an account"))
    }

    /// Membership, not a lookup: a lookup cannot tell a legitimately identical value from a missing entry falling
    /// back to English.
    @Test func theKeyResolvesInEveryLanguage() throws {
        for language in AppLanguage.allCases where language != .english {
            let folder = try #require(Bundle.main.path(forResource: language.code, ofType: "lproj"),
                                      "\(language.code) folder")
            let path = (folder as NSString).appendingPathComponent("Localizable.strings")
            let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String],
                                     "\(language.code) table")
            #expect(table[Self.key]?.isEmpty == false, "\(language.code) lacks the agreement footnote")
        }
    }
}
