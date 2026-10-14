import Foundation
import Testing
@testable import lily

/// The place rule the event and tournament drafts share: the name typed and the spot picked, judged in form order against
/// the backend's UTF-16 count.
@MainActor
struct PlaceDraftTests {
    private let limit = AppConfig.Events.Creation.locationNameMaxLength
    /// Berlin, where the fixtures play.
    private let spot = Coordinate(latitude: 52.52, longitude: 13.405)
    /// Munich, so a spot the draft was not given is told apart from `spot`.
    private let elsewhere = Coordinate(latitude: 48.1374, longitude: 11.5755)

    @Test func aBlankNameIsMissing() {
        #expect(PlaceDraft(name: "", coordinate: spot).issues(maxLength: limit).first == .nameMissing)
        #expect(PlaceDraft(name: "  \n", coordinate: spot).issues(maxLength: limit).first == .nameMissing)
    }

    @Test func aNameIsCountedInUTF16UnitsAgainstTheLimit() {
        let ascii = String(repeating: "x", count: limit)
        #expect(PlaceDraft(name: ascii, coordinate: spot).issues(maxLength: limit).isEmpty)

        let withEmoji = String(repeating: "x", count: limit - 1) + "🎾"
        #expect(withEmoji.count == limit, "as many characters as the limit, one unit more on the wire")
        #expect(PlaceDraft(name: withEmoji, coordinate: spot).issues(maxLength: limit) == [.nameTooLong])
    }

    @Test func theNameIsTrimmedBeforeItIsJudged() {
        let draft = PlaceDraft(name: " Park ", coordinate: spot)
        #expect(draft.issues(maxLength: limit).isEmpty)
        #expect(draft.trimmedName == "Park")

        let padded = PlaceDraft(name: " \(String(repeating: "x", count: limit)) ", coordinate: spot)
        #expect(padded.issues(maxLength: limit).isEmpty, "the padding is not counted")
    }

    @Test func aMissingSpotIsReportedAfterTheName() {
        #expect(PlaceDraft(name: "", coordinate: nil).issues(maxLength: limit) == [.nameMissing, .coordinateMissing])
        #expect(PlaceDraft(name: "Park", coordinate: nil).issues(maxLength: limit) == [.coordinateMissing])
    }

    @Test func aCompletePlaceHasNoIssues() {
        #expect(PlaceDraft(name: "Park", coordinate: spot).issues(maxLength: limit).isEmpty)
    }

    @Test func theLocationCarriesTheTrimmedNameAtTheGivenSpot() {
        let expected = EventLocation(name: "Park", coordinate: spot)
        #expect(PlaceDraft(name: " Park ", coordinate: spot).location(at: spot) == expected)
        #expect(PlaceDraft(name: "Park", coordinate: elsewhere).location(at: spot) == expected,
                "the caller resolves the spot; the draft's own does not decide")
    }
}
