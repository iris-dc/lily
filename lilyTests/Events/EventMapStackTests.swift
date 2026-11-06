import Foundation
import Testing
@testable import lily

/// Events on one spot of the map stack into one pin, so the one behind stays selectable.
@MainActor
struct EventMapStackTests {
    private static let berlin = AppConfig.Location.mockCenter
    private static let munich = Coordinate(latitude: 48.1374, longitude: 11.5755)

    private func event(_ title: String, at coordinate: Coordinate) -> SportEvent {
        var draft = EventDraft(startsAt: EventDraftTests.now)
        draft.fillRequired(coordinate: coordinate)
        draft.title = title
        return draft.makeEvent(hostUserId: "u-1", hostName: "Jo", coordinate: coordinate)
    }

    @Test func distinctSpotsStaySinglePinsInFeedOrder() {
        let events = [event("A", at: Self.berlin), event("B", at: Self.munich)]
        let stacks = EventMapStack.stacks(of: events)

        #expect(stacks.count == 2)
        #expect(stacks.map(\.events) == [[events[0]], [events[1]]])
        #expect(stacks[0].title == "A" && stacks[1].title == "B", "a single pin is labelled with its event")
    }

    /// Geocoding one typed name twice lands on identical coordinates; float jitter within about 11 m counts as the
    /// same spot too, and the stack keeps the feed's order and the shared place as its label.
    @Test func theSameSpotStacksAndIsLabelledWithThePlace() {
        let jitter = Coordinate(latitude: Self.berlin.latitude + 0.00001, longitude: Self.berlin.longitude)
        let events = [event("A", at: Self.berlin), event("B", at: Self.munich), event("C", at: jitter)]

        let stacks = EventMapStack.stacks(of: events)

        #expect(stacks.count == 2)
        #expect(stacks[0].events.map(\.title) == ["A", "C"] && stacks[1].events.map(\.title) == ["B"])
        #expect(stacks[0].title == "Test Park", "a stack is labelled with the place the events share")
        #expect(stacks[0].coordinate == Self.berlin, "the first event's spot is where the pin stands")
        #expect(stacks[0].id == EventMapStack.stacks(of: [events[0]])[0].id, "the id survives reloads")
    }

    /// Spots further apart than the radius stay their own pins.
    @Test func nearbyButDistinctSpotsDoNotStack() {
        let apart = Coordinate(latitude: Self.berlin.latitude + 0.001, longitude: Self.berlin.longitude)
        #expect(EventMapStack.stacks(of: [event("A", at: Self.berlin), event("B", at: apart)]).count == 2)
    }

    /// About a metre apart but either side of a fourth-decimal rounding boundary: a grid split them into two pins
    /// drawn over each other.
    @Test func spotsEitherSideOfARoundingBoundaryStack() {
        let below = Coordinate(latitude: 52.520_149, longitude: 13.405)
        let above = Coordinate(latitude: 52.520_151, longitude: 13.405)

        let stacks = EventMapStack.stacks(of: [event("A", at: below), event("B", at: above)])

        #expect(stacks.count == 1)
        #expect(stacks.first?.events.map(\.title) == ["A", "B"])
    }

    /// Membership is judged against a stack's first spot, so a chain of neighbours never drifts a pin across a block.
    @Test func distanceIsMeasuredFromTheStacksFirstSpot() {
        let first = Coordinate(latitude: 52.52, longitude: 13.405)
        let near = Coordinate(latitude: 52.520_07, longitude: 13.405)
        let far = Coordinate(latitude: 52.520_14, longitude: 13.405)

        let stacks = EventMapStack.stacks(of: [event("A", at: first), event("B", at: near), event("C", at: far)])

        #expect(stacks.map { $0.events.map(\.title) } == [["A", "B"], ["C"]])
    }

    /// Two stacks more than the radius apart whose first spots round to the same key still get distinct ids.
    @Test func stacksSharingARoundedKeyKeepDistinctIDs() {
        let one = Coordinate(latitude: 52.520_051, longitude: 13.405_051)
        let other = Coordinate(latitude: 52.520_149, longitude: 13.405_149)

        let stacks = EventMapStack.stacks(of: [event("A", at: one), event("B", at: other)])

        #expect(stacks.count == 2)
        #expect(Set(stacks.map(\.id)).count == 2)
    }
}
