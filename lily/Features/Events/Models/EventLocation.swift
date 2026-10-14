import Foundation

/// The place of events, groups, tournaments and match schedules: a name at a coordinate, in the backend's
/// `LocationDto` shape (the coordinate nested, never flattened).
nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate

    /// Meters from `origin`, or `nil` while the user's position is unknown: the one distance rule the event, group
    /// and tournament cards share.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: coordinate.distance(to: $0), unit: .meters) }
    }
}
