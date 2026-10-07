import Testing
@testable import lily

struct SportGroupCaptionTests {
    @Test func namesMembersAndType() {
        let group = SportGroup.fixture(type: .football, memberCount: 34)
        #expect(group.caption() == "34 members · Football")
    }

    @Test func skipsAMissingTypeAndAppendsTheSuffix() {
        let group = SportGroup.fixture(type: nil, memberCount: 1)
        #expect(group.caption(suffix: "Joined") == "1 member · Joined")
    }

    /// The place line of a tile: the name, then the distance once the position is known; nothing without a place.
    @Test func placeCaptionNamesThePlaceAndAppendsTheDistance() {
        let park = EventLocation(name: "Görlitzer Park", coordinate: AppConfig.Location.mockCenter)
        let located = SportGroup.fixture(location: park)
        #expect(located.placeCaption(distance: nil) == "Görlitzer Park")
        #expect(located.placeCaption(distance: "1.2 km") == "Görlitzer Park · 1.2 km")
        #expect(SportGroup.fixture().placeCaption(distance: "1.2 km") == nil)
    }

    /// A tournament's room names what it is and how many players are in; its mark is the trophy.
    @Test func aTournamentRoomReadsTournamentAndItsPlayers() {
        let room = SportGroup.tournamentRoomFixture(memberCount: 6)
        #expect(room.caption() == "Tournament · 6 players")
        #expect(room.caption(suffix: "Active today") == "Tournament · 6 players · Active today")
        #expect(room.avatarSymbol == DesignTokens.Symbols.tournament && SportGroup.fixture().avatarSymbol == nil)
    }

    /// A conversation's two members and missing type say nothing worth a row; the caption names what it is.
    @Test func aConversationReadsDirectMessage() {
        let conversation = SportGroup.conversationFixture()
        #expect(conversation.caption() == "Direct message")
        #expect(conversation.caption(suffix: "Active today") == "Direct message · Active today")
    }
}
