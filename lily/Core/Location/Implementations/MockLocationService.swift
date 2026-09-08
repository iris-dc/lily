import Foundation

/// Fixed position for previews, tests and the simulator.
final class MockLocationService: LocationService {
    private let coordinate: Coordinate?

    init(coordinate: Coordinate? = AppConfig.Location.mockCenter) {
        self.coordinate = coordinate
    }

    func currentLocation() async -> Coordinate? { coordinate }
}
