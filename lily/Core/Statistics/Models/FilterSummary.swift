import Foundation

/// The shape of a filter, without its values: which criteria were used, not the price cap, the dates or the place.
nonisolated struct FilterSummary: Encodable, Equatable, Sendable {
    /// Wire names in a fixed order, so equal selections encode equally, and never more than
    /// `AppConfig.Statistics.maxFilterTypes`: every known type fits, only a filter holding unknown names could exceed the
    /// cap, and that one sends the first names in order rather than earning the 400 that drops the whole batch.
    let types: [String]
    let maxDistanceMeters: Double?
    let hasMaxPrice: Bool
    let skillLevel: SkillLevel?
    let hasDateWindow: Bool
    let openSpotsOnly: Bool

    init(_ filter: EventFilter) {
        types = Array(filter.types.map(\.wireName).sorted().prefix(AppConfig.Statistics.maxFilterTypes))
        maxDistanceMeters = filter.maxDistanceMeters
        hasMaxPrice = filter.maxPrice != nil
        skillLevel = filter.skillLevel
        hasDateWindow = filter.dateWindow != nil
        openSpotsOnly = filter.openSpotsOnly
    }
}
