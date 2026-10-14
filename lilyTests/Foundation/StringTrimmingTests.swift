import Testing
@testable import lily

struct StringTrimmingTests {
    @Test func trimmedDropsSurroundingWhitespaceAndNewlines() {
        #expect("  Kreuzberg Kickers \n\t".trimmed == "Kreuzberg Kickers")
    }

    @Test func trimmedKeepsInnerWhitespace() {
        #expect("Sunset  5-a-side".trimmed == "Sunset  5-a-side")
    }

    /// A field the user cleared and one they filled with spaces are the same thing to the payload: nothing.
    @Test func nonBlankTrimmedIsNilForEmptyAndForWhitespaceOnlyText() {
        #expect("".nonBlankTrimmed == nil)
        #expect(" \n\t".nonBlankTrimmed == nil)
    }

    @Test func nonBlankTrimmedKeepsTheTrimmedText() {
        #expect(" Marta ".nonBlankTrimmed == "Marta")
    }

    @Test func aNilOptionalTrimsToEmptyAndHasNoNonBlankText() {
        let missing: String? = nil
        #expect(missing.trimmed.isEmpty)
        #expect(missing.nonBlankTrimmed == nil)
    }

    @Test func aWrappedOptionalTrimsLikeItsText() {
        #expect(Optional(" x ").trimmed == "x")
        #expect(Optional("   ").nonBlankTrimmed == nil)
    }
}
