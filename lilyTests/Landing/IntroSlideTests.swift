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

    /// The detail miniature opens a game the user could join, skipping a full one, and falls back to the first game
    /// when every one is full.
    @Test func theContentPicksAGameWithASpotFreeForTheJoinSlide() throws {
        let events = IntroFixtures.events(now: .now)
        let full = try #require(events.first { $0.isFull })
        let open = try #require(events.first { !$0.isFull })

        #expect(IntroContent(events: events).events.count == IntroFixtures.eventCount)
        #expect(IntroContent(events: [full, open]).joinEvent == open)
        #expect(IntroContent(events: [full]).joinEvent == full)
        #expect(IntroContent(events: []).joinEvent == nil)
    }

    @Test func theChatMiniatureHasItsLines() {
        #expect(!AppBranding.Intro.Chat.question.isEmpty)
        #expect(!AppBranding.Intro.Chat.answer.isEmpty)
        #expect(!AppBranding.Intro.Chat.followUp.isEmpty)
        #expect(!IntroFixtures.groupName.initials.isEmpty)
    }
}
