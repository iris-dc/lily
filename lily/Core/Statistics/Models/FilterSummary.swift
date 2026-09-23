import Foundation

/// The shape of a filter, without its values: which criteria were used, not the price cap, the dates or the place.
nonisolated struct FilterSummary: Encodable, Equatable, Sendable {
    /// Wire names in a fixed order, so equal selections encode equally.
    let types: [String]
    let maxDistanceMeters: Double?
    let hasMaxPrice: Bool
    let skillLevel: SkillLevel?
    let hasDateWindow: Bool
    let openSpotsOnly: Bool

    init(_ filter: EventFilter) {
        types = filter.types.map(\.rawValue).sorted()
        maxDistanceMeters = filter.maxDistanceMeters
        hasMaxPrice = filter.maxPrice != nil
        skillLevel = filter.skillLevel
        hasDateWindow = filter.dateWindow != nil
        openSpotsOnly = filter.openSpotsOnly
    }
}
