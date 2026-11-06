import Testing
@testable import lily

@MainActor
@Suite("Place match policy")
struct PlaceMatchPolicyTests {
    private let halfRegion = AppConfig.Events.placeSearchRegionMeters / 2

    @Test func aCityOrAnAddressStandsWhereverItIs() {
        #expect(PlaceMatchPolicy.isUsable(isPointOfInterest: false, distanceMeters: 520_000))
        #expect(PlaceMatchPolicy.isUsable(isPointOfInterest: false, distanceMeters: nil))
    }

    @Test func aPointOfInterestStandsOnlyNearTheBias() {
        #expect(PlaceMatchPolicy.isUsable(isPointOfInterest: true, distanceMeters: halfRegion))
        #expect(!PlaceMatchPolicy.isUsable(isPointOfInterest: true, distanceMeters: halfRegion + 1))
    }

    @Test func withoutABiasAPointOfInterestStands() {
        #expect(PlaceMatchPolicy.isUsable(isPointOfInterest: true, distanceMeters: nil))
    }
}
