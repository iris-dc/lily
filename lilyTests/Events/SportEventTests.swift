import Foundation
import Testing
@testable import lily

struct SportEventTests {
    @Test func fixturesLieWithinTheDemoRadius() {
        let center = AppConfig.Location.mockCenter
        for event in MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize) {
            #expect(event.location.coordinate.distance(to: center) < 5_000)
        }
    }

    @Test func distanceIsNilWithoutOrigin() {
        let event = MockEventFixtures.make(now: .now, count: 1)[0]
        #expect(event.distance(from: nil) == nil)
        #expect(event.distance(from: event.location.coordinate)?.value == 0)
    }

    @Test func nearlyFullFollowsConfiguredRatio() {
        #expect(!makeEvent(capacity: 4, participants: 1).isNearlyFull)
        #expect(makeEvent(capacity: 4, participants: 3).isNearlyFull)
        #expect(!makeEvent(capacity: 4, participants: 4).isNearlyFull)
    }

    private func makeEvent(capacity: Int, participants: Int) -> SportEvent {
        .fixture(capacity: capacity, participants: participants)
    }

    @Test func capacityMath() {
        let event = makeEvent(capacity: 4, participants: 1)
        #expect(event.spotsLeft == 3)
        #expect(event.fillRatio == 0.25)
        #expect(!event.isFull)
    }

    @Test func fullEventReportsNoSpots() {
        let event = makeEvent(capacity: 4, participants: 4)
        #expect(event.isFull)
        #expect(event.spotsLeft == 0)
        #expect(event.fillRatio == 1)
    }

    /// The backend's listing rule, repeated on device for the mock feed and the local insert into Explore.
    @Test func onlyAPrivateGroupsGameIsUnlisted() {
        let kickers = EventGroupRef(id: "k", name: "Kickers", visibility: .public, isDeleted: false)
        let padel = EventGroupRef(id: "p", name: "Padel", visibility: .private, isDeleted: false)

        #expect(SportEvent.fixture().isListed)
        #expect(SportEvent.fixture(group: kickers).isListed)
        #expect(!SportEvent.fixture(group: padel).isListed)
    }

    @Test func zeroCapacityDoesNotDivideByZero() {
        let event = makeEvent(capacity: 0, participants: 0)
        #expect(event.fillRatio == 0)
        #expect(event.isFull)
    }

    @Test func overCapacityClampsFillRatio() {
        let event = makeEvent(capacity: 4, participants: 6)
        #expect(event.fillRatio == 1)
        #expect(event.isFull)
        #expect(event.spotsLeft == 0)
    }

    @Test func availabilityCopyAgreesBetweenShortAndLongForms() {
        let full = makeEvent(capacity: 4, participants: 4)
        #expect(full.availabilityText == "Full")
        #expect(full.capacityText == "Full")

        let oneLeft = makeEvent(capacity: 4, participants: 3)
        #expect(oneLeft.availabilityText == "1 spot left")
        #expect(oneLeft.capacityText == "3 of 4 joined")

        let manyLeft = makeEvent(capacity: 4, participants: 1)
        #expect(manyLeft.availabilityText == "3 spots left")
        #expect(manyLeft.capacityText == "1 of 4 joined")
    }

    @Test func participationDefaultsToNotJoined() {
        #expect(!makeEvent(capacity: 4, participants: 1).participates)
        #expect(makeEvent(capacity: 4, participants: 1).updatingParticipation(count: 2, isJoined: true).participates)
    }

    @Test func hostIsRecognisedOnlyByAKnownId() {
        let fixture = makeEvent(capacity: 4, participants: 1)
        #expect(!fixture.isHosted(by: nil))
        #expect(!fixture.isHosted(by: "u-1"))

        let hosted = SportEvent.fixture(hostUserId: "u-1", isJoined: true)
        #expect(hosted.isHosted(by: "u-1"))
        #expect(!hosted.isHosted(by: "u-2"))
        #expect(!hosted.isHosted(by: nil))
    }

    @Test func updatingParticipationKeepsEverythingElse() {
        let event = makeEvent(capacity: 4, participants: 1).updatingParticipation(count: 1, isJoined: false)
        let joined = event.updatingParticipation(count: 2, isJoined: true)
        #expect(joined.participantCount == 2)
        #expect(joined.isJoined == true)
        #expect(joined.updatingParticipation(count: 1, isJoined: false) == event)
    }
}

/// `SportEvent` is the wire shape of the backend's `Event`.
struct SportEventCodingTests {
    private let decoder = APIJSONCoding.makeDecoder()

    @Test func decodesTheContractEvent() throws {
        let event = try decoder.decode(SportEvent.self, from: Data(ContractSamples.event.utf8))
        #expect(event.id == "evt_01J")
        #expect(event.type == .football)
        #expect(event.startsAt == Date(timeIntervalSince1970: 1_789_318_800))
        #expect(event.location.coordinate == Coordinate(latitude: 52.529, longitude: 13.387))
        #expect(event.capacity == 10)
        #expect(event.participantCount == 6)
        #expect(event.hostUserId == "seed-marta")
        #expect(event.hostName == "Marta")
        #expect(event.isJoined == false)
        #expect(event.description == "Bring both colours")
        #expect(event.lookingFor == nil)
        #expect(event.skillLevel == .intermediate)
        #expect(event.price == Price(amount: 7.5, currencyCode: "EUR"))
    }

    /// Optional fields are absent rather than `null`.
    @Test func optionalFieldsMayBeAbsent() throws {
        let event = try decoder.decode(SportEvent.self, from: Data(ContractSamples.minimalEvent.utf8))
        #expect(event.hostUserId == nil)
        #expect(event.isJoined == nil)
        #expect(!event.participates)
        #expect(event.type == .other)
        #expect(event.description == nil)
        #expect(event.price == nil)
    }

    /// A grouped game carries its group as the backend stamps it; an ungrouped one has none, and a join keeps it.
    @Test func groupDecodesFromTheGroupKeyAndSurvivesAJoin() throws {
        let grouped = try decoder.decode(SportEvent.self, from: Data(ContractSamples.groupedEvent.utf8))
        let ungrouped = try decoder.decode(SportEvent.self, from: Data(ContractSamples.event.utf8))

        let group = try #require(grouped.group)
        let expected = EventGroupRef(id: "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d",
                                     name: "Kreuzberg Kickers",
                                     visibility: .public,
                                     isDeleted: false)
        #expect(group == expected)
        #expect(group.isLinkable)
        #expect(ungrouped.group == nil)
        #expect(grouped.updatingParticipation(count: 7, isJoined: true).group == group)
    }

    /// The wire keys are the property names; `type` in particular must not drift back to "sport".
    @Test func wireKeysMatchTheContract() throws {
        let event = MockEventFixtures.make(now: .now, count: 1)[0]
        let json = try #require(String(bytes: APIJSONCoding.makeEncoder().encode(event), encoding: .utf8))
        #expect(json.contains(#""type":"football""#))
        #expect(json.contains(#""participantCount":6"#))
        #expect(!json.contains(#""sport""#))
    }
}
