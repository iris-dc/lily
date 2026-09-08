import Testing
@testable import lily

struct CoordinateTests {
    @Test func distanceToSelfIsZero() {
        let point = Coordinate(latitude: 52.52, longitude: 13.405)
        #expect(point.distance(to: point) == 0)
    }

    @Test func distanceMatchesKnownValue() {
        // Berlin -> Hamburg, roughly 255 km.
        let berlin = Coordinate(latitude: 52.5200, longitude: 13.4050)
        let hamburg = Coordinate(latitude: 53.5511, longitude: 9.9937)
        let km = berlin.distance(to: hamburg) / 1000
        #expect(km > 250 && km < 260)
    }

    @Test func distanceIsSymmetric() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 1, longitude: 1)
        #expect(abs(a.distance(to: b) - b.distance(to: a)) < 0.001)
    }
}

@MainActor
struct MockLocationServiceTests {
    @Test func returnsConfiguredCoordinate() async {
        #expect(await MockLocationService().currentLocation() == AppConfig.Location.mockCenter)
        #expect(await MockLocationService(coordinate: nil).currentLocation() == nil)
    }
}
