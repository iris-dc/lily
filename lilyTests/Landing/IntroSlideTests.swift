import Testing
import UIKit
@testable import lily

struct IntroSlideTests {
    @Test func slidesComeInSwipeOrderAndStartAtEvents() {
        #expect(IntroSlide.allCases == [.events, .join, .groups, .tournaments])
        #expect(IntroSlide.first == .events)
    }

    /// The groups and tournaments slides show only while their features are on (the groups slide shows a room, so its
    /// flag is the groups feature together with the chat); the first two always do.
    @Test func groupsAndTournamentsFollowTheirFlags() {
        #expect(IntroSlide.shown(groups: true, tournaments: true) == IntroSlide.allCases)
        #expect(IntroSlide.shown(groups: false, tournaments: false) == [.events, .join])
        #expect(IntroSlide.shown(groups: true, tournaments: false) == [.events, .join, .groups])
        #expect(IntroSlide.shown(groups: false, tournaments: true) == [.events, .join, .tournaments])
        #expect(IntroSlide.shown().contains(.groups) == (AppConfig.FeatureFlags.groups && AppConfig.FeatureFlags.chat))
        #expect(IntroSlide.shown().contains(.tournaments) == AppConfig.FeatureFlags.tournaments)
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

    /// The detail miniature opens an event the user could join (one without a limit counts as open), skipping a full
    /// one, and falls back to the first event when every one is full; the cards and the tournament are kept as given.
    @Test func theContentPicksAnEventWithASpotFreeForTheJoinSlide() {
        let full = SportEvent.fixture(id: "full", capacity: 4, participants: 4)
        let open = SportEvent.fixture(id: "open", capacity: 4, participants: 1)
        let unlimited = SportEvent.fixture(id: "any", capacity: nil, participants: 50)
        let tournament = TournamentDetail.fixture()

        #expect(IntroContent(events: [full, open], tournament: tournament).joinEvent == open)
        #expect(IntroContent(events: [full, unlimited], tournament: tournament).joinEvent == unlimited)
        #expect(IntroContent(events: [full], tournament: tournament).joinEvent == full)
        #expect(IntroContent(events: [], tournament: tournament).joinEvent == nil)
        #expect(IntroContent(events: [full, open], tournament: tournament).events == [full, open])
        #expect(IntroContent(events: [], tournament: tournament).tournament == tournament)
    }

    @Test func theMiniatureShowsAsManyCardsAsTheLivePreview() {
        #expect(IntroFixtures.events(now: .now).count == AppConfig.Events.landingPreviewCount)
    }

    /// The bracket miniature shows a knockout under way, organised by a person rather than the mock's caller (whose
    /// seat reads "Organised by You"), with both semi-finals in so the finalists stand in the final.
    @Test func theTournamentIsUnderWayWithTheFinalistsKnown() throws {
        let detail = IntroFixtures.tournament(now: .now)

        #expect(detail.tournament.status == .inProgress)
        #expect(detail.tournament.format == .singleElimination)
        #expect(detail.tournament.organizerName == IntroFixtures.senderName)
        #expect(detail.matches.count == 3)
        #expect(detail.matches.filter(\.isDecided).count == 2)
        let finalMatch = try #require(detail.matches.first { $0.nextMatchId == nil })
        #expect(finalMatch.entryAId != nil && finalMatch.entryBId != nil && !finalMatch.isDecided)
        #expect(detail.entryName(finalMatch.entryAId) != AppBranding.Tournaments.toBeDecided)
    }
}
