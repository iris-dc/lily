import Testing
@testable import lily

/// Code points, as Laurel counts a display name: an emoji is one, where `wireLength` counts two.
struct CodePointsTests {
    @Test func codePointsCountScalarsNotUTF16Units() {
        #expect("🏓🏓".codePointCount == 2 && "🏓🏓".wireLength == 4 && "Alex".codePointCount == 4)
    }

    @Test func prefixNeverCutsInsideAScalar() {
        #expect("🏓🏓🏓".prefix(codePoints: 2) == "🏓🏓")
        #expect("Alex".prefix(codePoints: 10) == "Alex" && "".prefix(codePoints: 3).isEmpty)
    }
}
