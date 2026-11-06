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

    /// A map pick is the user's choice and forgets the suggestion; clearing the spot keeps the rest.
    @Test func aMapPickMarksTheSpotPickedAndForgetsTheSuggestion() {
        var picked = draft(name: "Gda")
        picked.apply(gdansk)
        picked.pickSpot(AppConfig.Location.mockCenter)
        #expect(picked.coordinate == AppConfig.Location.mockCenter && picked.spotPickedOnMap && picked.suggestedName == nil)

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
}
