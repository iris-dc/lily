import Foundation
import Testing
@testable import lily

struct SportEventTests {
    @Test func fixturesLieWithinTheDemoRadius() {
        let center = AppConfig.Location.mockCenter
        for event in MockEventFixtures.make(now: .now, count: 8) {
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
        SportEvent(
            id: "e",
            title: "t",
            sport: .tennis,
            startsAt: .now,
            location: EventLocation(name: "l", coordinate: AppConfig.Location.mockCenter),
            capacity: capacity,
            participantCount: participants,
            hostName: "h"
        )
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
        #expect(oneLeft.capacityText == "1 of 4 spots left")

        let manyLeft = makeEvent(capacity: 4, participants: 1)
        #expect(manyLeft.availabilityText == "3 spots left")
        #expect(manyLeft.capacityText == "3 of 4 spots left")
    }
}
