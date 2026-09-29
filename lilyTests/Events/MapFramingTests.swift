import MapKit
import Testing
@testable import lily

struct MapFramingTests {
    private let berlin = Coordinate(latitude: 52.52, longitude: 13.405)

    @Test func framesTheUserAtThePaddedFilterDiameter() throws {
        let region = try #require(MapFraming.initialRegion(userLocation: berlin, radiusMeters: 5_000))

        #expect(region.center.latitude == berlin.latitude)
        #expect(region.center.longitude == berlin.longitude)
        // 10 km across plus the padding; one degree of latitude is about 111 km.
        let expectedMeters = 10_000 * DesignTokens.Layout.mapRegionPadding
        #expect(abs(region.span.latitudeDelta - expectedMeters / 111_000) < 0.005)
    }

    @Test func fallsBackToTheDefaultRadiusWithoutOne() throws {
        let region = try #require(MapFraming.initialRegion(userLocation: berlin, radiusMeters: nil))
        let expected = try #require(MapFraming.initialRegion(userLocation: berlin,
                                                             radiusMeters: AppConfig.Events.defaultFilterRadiusMeters))

        #expect(region.span.latitudeDelta == expected.span.latitudeDelta)
    }

    @Test func hasNoRegionWhileThePositionIsUnknown() {
        #expect(MapFraming.initialRegion(userLocation: nil, radiusMeters: 5_000) == nil)
    }
}
