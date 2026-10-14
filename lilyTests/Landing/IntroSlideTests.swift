import Testing
import UIKit
@testable import lily

struct IntroSlideTests {
    @Test func slidesComeInSwipeOrderAndStartAtDiscover() {
        #expect(IntroSlide.allCases == [.discover, .join, .create])
        #expect(IntroSlide.first == .discover)
    }

    /// Every slide draws two headline lines (the second in the accent) and a message; an empty one would be a
    /// catalog key gone missing.
    @Test func everySlideHasTwoHeadlineLinesAndAMessage() {
        for slide in IntroSlide.allCases {
            #expect(slide.headline.count == 2)
            #expect(slide.headline.allSatisfy { !$0.isEmpty })
            #expect(!slide.message.isEmpty)
        }
    }

    /// A misspelt SF Symbol draws nothing, so the hint's glyph is checked here instead of by eye.
    @Test func theSwipeHintHasAGlyphThatExists() {
        #expect(UIImage(systemName: DesignTokens.Symbols.swipeUp) != nil)
    }

    /// The detail miniature opens a game the user could join (one without a limit counts as open), skipping a full
    /// one, and falls back to the first game when every one is full; the cards are kept as given.
    @Test func theContentPicksAGameWithASpotFreeForTheJoinSlide() {
        let full = SportEvent.fixture(id: "full", capacity: 4, participants: 4)
        let open = SportEvent.fixture(id: "open", capacity: 4, participants: 1)
        let unlimited = SportEvent.fixture(id: "any", capacity: nil, participants: 50)

        #expect(IntroContent(events: [full, open]).joinEvent == open)
        #expect(IntroContent(events: [full, unlimited]).joinEvent == unlimited)
        #expect(IntroContent(events: [full]).joinEvent == full)
        #expect(IntroContent(events: []).joinEvent == nil)
        #expect(IntroContent(events: [full, open]).events == [full, open])
    }

    /// The Explore miniature shows as many cards as the live preview it stands in for.
    @Test func theMiniatureShowsAsManyCardsAsTheLivePreview() {
        #expect(IntroFixtures.events(now: .now).count == AppConfig.Events.landingPreviewCount)
    }
}
