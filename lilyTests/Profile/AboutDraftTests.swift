import Foundation
import Testing
@testable import lily

/// The "About you" editor's validation: optional, so a blank is valid (it clears), and the cap is measured as the backend
/// measures it.
struct AboutDraftTests {
    @Test(arguments: ["", "  \n "])
    func aBlankIsValidAndClears(text: String) {
        let draft = AboutDraft(text: text)
        #expect(draft.isValid && draft.issues.isEmpty && draft.hint == nil && draft.trimmedText.isEmpty)
    }

    @Test func theTextIsMeasuredInCodePointsLikeTheBackend() {
        let limit = AppConfig.About.maxLength
        var draft = AboutDraft(text: String(repeating: "🏓", count: limit))
        #expect(draft.isValid, "an emoji is one code point, as Java's codePointCount says, though two UTF-16 units")

        draft.text += "x"

        #expect(draft.issues == [.tooLong] && !draft.isValid)
        #expect(draft.hint == AppBranding.About.tooLong(limit: limit))
        #expect(draft.hint?.contains("\(limit)") == true)
    }

    @Test func aTrimmedTextIsWhatIsSent() {
        let draft = AboutDraft(text: "  Padel on Sundays.  ")
        #expect(draft.trimmedText == "Padel on Sundays." && draft.isValid && draft.hint == nil)
    }
}
