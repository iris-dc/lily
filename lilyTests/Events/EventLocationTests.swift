import Foundation
import Testing
@testable import lily

struct EventLocationTests {
    private let place = EventLocation(name: "Park", coordinate: AppConfig.Location.mockCenter)
    /// 0.03 degrees of latitude south of the place: about 3.3 km.
    private let origin = Coordinate(latitude: 52.49, longitude: 13.405)

    @Test func theRuleAnswersMetersFromTheOriginOrNilWithoutOne() throws {
        #expect(place.distance(from: nil) == nil, "no position, no distance")
        #expect(place.distance(from: place.coordinate)?.value == 0)

        let distance = try #require(place.distance(from: origin))
        #expect(distance.unit == .meters)
        #expect((3_200..<3_500).contains(distance.value))
    }

    @Test func distanceIsOneRuleForEventsGroupsAndTournaments() {
        let event = SportEvent.fixture()
        #expect(event.distance(from: origin) == event.location.distance(from: origin))
        #expect(event.distance(from: nil) == nil)

        let tournament = Tournament.fixture()
        #expect(tournament.distance(from: origin) == tournament.location.distance(from: origin))
        #expect(tournament.distance(from: nil) == nil)

        let placed = SportGroup.fixture(location: place)
        #expect(placed.distance(from: origin) == place.distance(from: origin))
        #expect(placed.distance(from: nil) == nil)
        #expect(SportGroup.fixture().distance(from: origin) == nil, "no place, no distance")
    }
}
