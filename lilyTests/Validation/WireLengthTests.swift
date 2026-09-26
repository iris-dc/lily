import Testing
@testable import lily

struct WireLengthTests {
    /// The backend counts UTF-16 units (Java's `String.length()`), so an emoji is two, not one.
    @Test func countsUTF16UnitsLikeTheBackend() {
        #expect("abc".wireLength == 3)
        #expect("😀".count == 1)
        #expect("😀".wireLength == 2)
    }

    @Test func nilTextHasNoLength() {
        let missing: String? = nil
        let present: String? = "ab"
        #expect(missing.wireLength == 0)
        #expect(present.wireLength == 2)
    }

    /// A cap in UTF-16 units keeps whole characters: an emoji that would straddle the limit is dropped, not split.
    @Test func prefixByWireLengthKeepsWholeCharactersWithinTheCap() {
        #expect("abcdef".prefix(wireLength: 3) == "abc")
        #expect("abc".prefix(wireLength: 5) == "abc")
        #expect("😀😀😀".prefix(wireLength: 5) == "😀😀")
        #expect("ab😀".prefix(wireLength: 3) == "ab")
        #expect("abc".prefix(wireLength: 0).isEmpty)
    }
}
