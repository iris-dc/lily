import Foundation
import Testing
@testable import lily

/// The draft's place bookkeeping: when the form asks for suggestions, what a tapped suggestion and a map pick change,
/// and which fields count as content.
@MainActor
struct EventDraftPlaceTests {
    private let gdansk = PlaceSuggestion(title: "Gdansk",
                                         subtitle: "Poland",
                                         coordinate: .init(latitude: 54.352, longitude: 18.6466))

    private func draft(name: String) -> EventDraft {
        var draft = EventDraft.fixture(now: EventDraftTests.now)
        draft.locationName = name
        return draft
    }

    /// Too short, blank, or the name a suggestion just set asks for nothing; anything else asks with the trimmed text.
    @Test func suggestionsAreAskedForATypedNameLongEnough() {
        #expect(draft(name: " G ").placeSuggestionQuery == nil)
        #expect(draft(name: "   ").placeSuggestionQuery == nil)
        #expect(draft(name: " Gd ").placeSuggestionQuery == "Gd")
        var picked = draft(name: "Gdansk")
        picked.suggestedName = "Gdansk"
        #expect(picked.placeSuggestionQuery == nil)
        picked.locationName = "Gdansk Oliwa"
        #expect(picked.placeSuggestionQuery == "Gdansk Oliwa", "a reworded name asks again")
    }

    /// A tapped suggestion fills the name and the spot, and leaves the spot a proposal so a later name moves it.
    @Test func applyingASuggestionFillsTheNameAndTheProposedSpot() {
        var typed = draft(name: "Gda")
        typed.spotPickedOnMap = true
        typed.apply(gdansk)
        #expect(typed.locationName == "Gdansk" && typed.coordinate == gdansk.coordinate)
        #expect(typed.suggestedName == "Gdansk" && !typed.spotPickedOnMap)
    }

    /// A map pick is the user's choice and forgets the suggestion; clearing the spot clears the map-pick mark with
    /// it and keeps the name bookkeeping.
    @Test func aMapPickMarksTheSpotPickedAndForgetsTheSuggestion() {
        var picked = draft(name: "Gda")
        picked.apply(gdansk)
        picked.pickSpot(AppConfig.Location.mockCenter)
        #expect(picked.coordinate == AppConfig.Location.mockCenter && picked.spotPickedOnMap && picked.suggestedName == nil)

        picked.pickSpot(nil)
        #expect(picked.coordinate == nil && !picked.spotPickedOnMap, "a cleared spot is no map pick")

        var suggested = draft(name: "Gda")
        suggested.apply(gdansk)
        suggested.pickSpot(nil)
        #expect(suggested.coordinate == nil && !suggested.spotPickedOnMap && suggested.suggestedName == "Gdansk")
    }

    /// The bookkeeping never reaches the wire, so it alone is no difference; any wire field is.
    @Test func theBookkeepingIsNotContent() {
        let stored = draft(name: "Park")
        var touched = stored
        (touched.spotPickedOnMap, touched.suggestedName) = (!stored.spotPickedOnMap, "Park")
        #expect(touched.hasSameContent(as: stored) && touched != stored)
        touched.locationName = "Mauerpark"
        #expect(!touched.hasSameContent(as: stored))
    }

    @Test func anEditedGameStartsWithItsSpotPicked() {
        let edited = EventDraft(editing: SportEvent.fixture(hostUserId: "host"))
        #expect(edited.spotPickedOnMap && edited.suggestedName == nil)
    }

    /// Round 5: typed text alone is no place. A tapped suggestion or a map pick makes the place chosen; editing the
    /// name after a pick drops the choice again.
    @Test func aPlaceCountsOnlyWhenChosen() {
        var typed = draft(name: "wgwgr")
        (typed.spotPickedOnMap, typed.suggestedName) = (false, nil)
        #expect(!typed.placeChosen)
        #expect(typed.issues(now: EventDraftTests.now) == [.placeNotChosen])

        typed.apply(gdansk)
        #expect(typed.placeChosen && typed.issues(now: EventDraftTests.now).isEmpty)

        typed.locationName = "Gdansk Oliwa"
        #expect(!typed.placeChosen, "editing the text after a pick clears the pick")
        #expect(typed.issues(now: EventDraftTests.now) == [.placeNotChosen])

        typed.pickSpot(AppConfig.Location.mockCenter)
        #expect(typed.placeChosen && typed.issues(now: EventDraftTests.now).isEmpty)
    }

    /// The GPS proposal under an untouched field is no choice either; only nothing at all is still "missing".
    @Test func theProposalAloneIsNotAChoice() {
        var proposed = draft(name: "")
        (proposed.spotPickedOnMap, proposed.suggestedName) = (false, nil)
        #expect(proposed.issues(now: EventDraftTests.now) == [.placeNotChosen])

        proposed.coordinate = nil
        #expect(proposed.issues(now: EventDraftTests.now) == [.placeMissing])
    }

    /// The detail line joins the stored name after a comma, never stands alone, and blank details change nothing.
    @Test func theDetailLineJoinsTheStoredNameAndNeverStandsAlone() {
        var drafted = draft(name: "Gdansk")
        drafted.locationDetail = " apt 4 "
        #expect(drafted.composedLocationName == "Gdansk, apt 4")
        #expect(drafted.makeEvent(hostUserId: "u", hostName: "Jo", coordinate: AppConfig.Location.mockCenter)
                    .locationName == "Gdansk, apt 4")

        drafted.locationDetail = "  "
        #expect(drafted.composedLocationName == "Gdansk")

        drafted.locationName = " "
        drafted.locationDetail = "apt 4"
        #expect(drafted.composedLocationName.isEmpty, "the detail never stands alone")
    }

    /// The composed name is judged against the wire cap; with only the spot given, the detail must leave
    /// `locationNameSpotReserve` for the reverse-geocoded address.
    @Test func theDetailCountsAgainstTheWireCap() {
        let limits = AppConfig.Events.Creation.self
        var drafted = draft(name: String(repeating: "x", count: limits.locationNameMaxLength - 4))
        drafted.locationDetail = "apt"
        #expect(drafted.issues(now: EventDraftTests.now) == [.locationNameTooLong], "name, separator and detail overflow")
        drafted.locationDetail = "a"
        #expect(drafted.issues(now: EventDraftTests.now).isEmpty)

        var spotOnly = draft(name: "")
        let room = limits.locationNameMaxLength - limits.locationNameSpotReserve
        spotOnly.locationDetail = String(repeating: "x", count: room)
        #expect(spotOnly.issues(now: EventDraftTests.now) == [.locationNameTooLong], "no room left for the address")
        spotOnly.locationDetail = String(repeating: "x", count: room - 2)
        #expect(spotOnly.issues(now: EventDraftTests.now).isEmpty)
    }

    /// A stored place is grandfathered whole: the edit starts chosen, the full stored name as the address and the
    /// detail line empty, so saving unchanged round-trips the name byte for byte.
    @Test func anEditedGameKeepsTheStoredNameWhole() {
        let event = SportEvent.fixture(hostUserId: "host")
        let edited = EventDraft(editing: event)
        #expect(edited.placeChosen && edited.locationDetail.isEmpty)
        #expect(edited.composedLocationName == event.locationName)
        #expect(edited.issues(now: event.startsAt.addingTimeInterval(-.hour),
                              rules: .editing(participantCount: event.participantCount)).isEmpty)
    }
}
