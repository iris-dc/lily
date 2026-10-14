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

    /// Laurel only ever receives the two-decimal text of `coarse` (its `CoarsePosition.round` is HALF_UP on that
    /// text, so a binary 1.005 could differ), hence what both sides must share is the printed value: this side keeps
    /// the given decimals with halves away from zero and prints them fixed (`String(format: "%.2f")`).
    @Test func roundingKeepsTheGivenDecimalsWithHalvesAwayFromZero() {
        #expect(Coordinate(latitude: 52.5449, longitude: -0.1251).rounded(toDecimals: 2)
                == Coordinate(latitude: 52.54, longitude: -0.13))
        #expect(Coordinate(latitude: 0.125, longitude: -0.125).rounded(toDecimals: 2)
                == Coordinate(latitude: 0.13, longitude: -0.13))
        #expect(Coordinate(latitude: 52.5, longitude: 13.4).rounded(toDecimals: 2) == Coordinate(latitude: 52.5, longitude: 13.4))
    }

    /// What Explore sends and what its staleness check compares must be one rounding.
    @Test func coarseRoundsToThePositionPrecision() {
        let point = Coordinate(latitude: 52.5449, longitude: 13.4051)
        #expect(point.coarse == point.rounded(toDecimals: AppConfig.Events.positionPrecision))
        #expect(point.coarse != point)
    }
}

@MainActor
struct MockLocationServiceTests {
    @Test func returnsConfiguredCoordinate() async {
        #expect(await MockLocationService().currentLocation() == AppConfig.Location.mockCenter)
        #expect(await MockLocationService(coordinate: nil).currentLocation() == nil)
    }
}
