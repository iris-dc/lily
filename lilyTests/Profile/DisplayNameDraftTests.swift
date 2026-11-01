import Foundation
import Testing
@testable import lily

/// The display name editor's validation: a blank is missing, the cap is measured as the backend measures it.
struct DisplayNameDraftTests {
    @Test(arguments: ["", "   "])
    func aBlankNameIsMissingAndHasNoHint(name: String) {
        let draft = DisplayNameDraft(name: name)
        #expect(draft.issues == [.nameMissing] && !draft.isValid && draft.hint == nil)
    }

    @Test func theNameIsMeasuredInCodePointsLikeTheBackend() {
        let limit = AppConfig.DisplayName.length.upperBound
        var draft = DisplayNameDraft(name: String(repeating: "🏓", count: limit))
        #expect(draft.isValid, "an emoji is one code point, as Java's codePointCount says, though two UTF-16 units")

        draft.name += "x"

        #expect(draft.issues == [.nameTooLong] && !draft.isValid)
        #expect(draft.hint == AppBranding.DisplayName.tooLong(limit: limit))
        #expect(draft.hint?.contains("\(limit)") == true)
    }

    @Test func aTrimmedNameIsWhatIsSent() {
        let draft = DisplayNameDraft(name: "  Alex Kim  ")
        #expect(draft.trimmedName == "Alex Kim" && draft.isValid && draft.hint == nil)
    }
}
