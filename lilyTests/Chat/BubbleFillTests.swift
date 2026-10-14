import Testing
@testable import lily

/// When a bubble's attachments are the bubble (pictures and videos alone, with no words and no quote) and when they sit
/// on the fill (a file card, a caption, a quote, a kind this build does not know, or no attachment at all).
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
