import Foundation
import Testing
@testable import lily

/// The organiser's schedule form, as `MatchScheduleDraft` holds it: what it opens with, what it sends, and what keeps
/// Save disabled.
struct MatchScheduleDraftTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let venue = AppConfig.Location.mockCenter
    private let spot = Coordinate(latitude: 52.49, longitude: 13.43)

    @Test func itOpensOnTheProposalAndSendsTheNamedPlaceAtTheSpotOrTheVenue() {
        let pitch = EventLocation(name: "Pitch 2", coordinate: spot)
        let proposal = MatchSchedule(scheduledAt: now.addingTimeInterval(3_600), location: pitch)
        var draft = MatchScheduleDraft(proposal: proposal, now: now)
        #expect(draft.scheduledAt == proposal.scheduledAt && draft.locationName == "Pitch 2" && draft.coordinate == spot)
        #expect(draft.earliest == now && draft.isValid)
        #expect(draft.schedule(venue: venue) == proposal)

        draft.coordinate = nil
        draft.locationName = "  Table two  "
        #expect(draft.location(venue: venue) == EventLocation(name: "Table two", coordinate: venue), "trimmed, at the venue")
        #expect(draft.location(venue: nil) == nil, "a name without any spot sends no place")

        draft.locationName = "   "
        #expect(draft.schedule(venue: venue) == MatchSchedule(scheduledAt: proposal.scheduledAt), "an empty name: the time alone")
    }

    @Test func aPastScheduleStaysWithinThePickerAndAnEmptyProposalStartsNow() {
        let past = now.addingTimeInterval(-7_200)
        let draft = MatchScheduleDraft(proposal: MatchSchedule(scheduledAt: past), now: now)
        #expect(draft.earliest == past && draft.scheduledAt == past && draft.locationName.isEmpty && draft.coordinate == nil)

        let fresh = MatchScheduleDraft(proposal: MatchSchedule(), now: now)
        #expect(fresh.scheduledAt == now && fresh.earliest == now && fresh.location(venue: venue) == nil)
    }

    @Test func aPlaceNameOverTheLimitHoldsTheSend() {
        var draft = MatchScheduleDraft(proposal: MatchSchedule(), now: now)
        draft.locationName = String(repeating: "x", count: AppConfig.Events.Creation.locationNameMaxLength + 1)
        #expect(!draft.isValid)
        draft.locationName = String(repeating: "x", count: AppConfig.Events.Creation.locationNameMaxLength)
        #expect(draft.isValid)
    }
}
