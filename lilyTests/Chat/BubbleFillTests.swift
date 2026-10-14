import Testing
@testable import lily

/// Pictures and videos alone are the bubble; a file card, a caption, a quote or an unknown kind puts them on the fill.
struct BubbleFillTests {
    @Test func aPictureAloneIsTheBubble() {
        #expect(BubbleFill.standsAlone(kinds: [.image], hasText: false, hasQuote: false))
    }

    @Test func aVideoAloneIsTheBubble() {
        #expect(BubbleFill.standsAlone(kinds: [.video], hasText: false, hasQuote: false))
        #expect(BubbleFill.standsAlone(kinds: [.image, .video], hasText: false, hasQuote: false))
    }

    @Test func aFileAloneKeepsTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [.file], hasText: false, hasQuote: false))
    }

    @Test func aPictureWithACaptionKeepsTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [.image], hasText: true, hasQuote: false))
    }

    @Test func aPictureWithAQuoteKeepsTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [.image], hasText: false, hasQuote: true))
    }

    @Test func wordsAloneKeepTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [], hasText: true, hasQuote: false))
        #expect(!BubbleFill.standsAlone(kinds: [], hasText: false, hasQuote: false))
    }

    @Test func aPictureNextToAFileKeepsTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [.image, .file], hasText: false, hasQuote: false))
    }

    @Test func anUnknownKindKeepsTheFill() {
        #expect(!BubbleFill.standsAlone(kinds: [.unknown("sticker")], hasText: false, hasQuote: false))
    }
}
