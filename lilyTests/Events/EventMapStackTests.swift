import Foundation
import Testing
@testable import lily

/// Events on one spot of the map stack into one pin, so the one behind stays selectable.
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

    /// Spots further apart than the rounding stay their own pins.
    @Test func nearbyButDistinctSpotsDoNotStack() {
        let apart = Coordinate(latitude: Self.berlin.latitude + 0.001, longitude: Self.berlin.longitude)
        #expect(EventMapStack.stacks(of: [event("A", at: Self.berlin), event("B", at: apart)]).count == 2)
    }
}
