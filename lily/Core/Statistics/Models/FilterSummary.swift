import Foundation

/// The shape of a filter, without its values: which criteria were used, not the dates or the place.
nonisolated struct FilterSummary: Encodable, Equatable, Sendable {
    /// Wire names in a fixed order, so equal selections encode equally, cut to `AppConfig.Statistics.maxFilterTypes`:
    /// Laurel answers a longer list with a 400 that drops the whole batch, and only unknown names could push a filter
    /// past the cap.
    let types: [String]
    let maxDistanceMeters: Double?
    let minAttendees: Int?
    /// Raw names in the cases' order; empty means any time.
    let timesOfDay: [String]
    let skillLevel: SkillLevel?
    let hasDateWindow: Bool
    let openSpotsOnly: Bool

    init(_ filter: EventFilter) {
        types = Array(filter.types.map(\.wireName).sorted().prefix(AppConfig.Statistics.maxFilterTypes))
        maxDistanceMeters = filter.maxDistanceMeters
        minAttendees = filter.minAttendees
        timesOfDay = TimeOfDay.allCases.filter(filter.timesOfDay.contains).map(\.rawValue)
        skillLevel = filter.skillLevel
        hasDateWindow = filter.dateWindow != nil
        openSpotsOnly = filter.openSpotsOnly
    }
}
