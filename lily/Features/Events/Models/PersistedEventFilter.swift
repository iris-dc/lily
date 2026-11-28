import Foundation

/// The part of an `EventFilter` worth keeping between launches: the types, the radius, the attendee floor, the parts
/// of the day, the level and the open-spots switch. The date window stays out, since a stored range goes stale within
/// days. Stored as JSON.
nonisolated struct PersistedEventFilter: Codable, Equatable, Sendable {
    /// Sorted by wire name, so equal selections store the same bytes.
    let types: [EventType]
    /// `nil` is "anywhere", as on the filter; the key is then absent.
    let maxDistanceMeters: Double?
    let minAttendees: Int?
    /// Raw names in the cases' order; kept as strings so a value from a newer build is dropped, never a crash.
    let timesOfDay: [String]
    let skillLevel: SkillLevel?
    let openSpotsOnly: Bool

    init(_ filter: EventFilter) {
        types = filter.types.sorted { $0.wireName < $1.wireName }
        maxDistanceMeters = filter.maxDistanceMeters
        minAttendees = filter.minAttendees
        timesOfDay = TimeOfDay.allCases.filter(filter.timesOfDay.contains).map(\.rawValue)
        skillLevel = filter.skillLevel
        openSpotsOnly = filter.openSpotsOnly
    }

    /// A filter kept by a build from before the parts of the day (2026-11-26) has no such key; it reads as none
    /// chosen, so the rest of the kept filter survives the update instead of being dropped by a decode failure.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        types = try container.decode([EventType].self, forKey: .types)
        maxDistanceMeters = try container.decodeIfPresent(Double.self, forKey: .maxDistanceMeters)
        minAttendees = try container.decodeIfPresent(Int.self, forKey: .minAttendees)
        timesOfDay = try container.decodeIfPresent([String].self, forKey: .timesOfDay) ?? []
        skillLevel = try container.decodeIfPresent(SkillLevel.self, forKey: .skillLevel)
        openSpotsOnly = try container.decode(Bool.self, forKey: .openSpotsOnly)
    }

    enum CodingKeys: String, CodingKey {
        case types, maxDistanceMeters, minAttendees, timesOfDay, skillLevel, openSpotsOnly
    }

    /// The filter as the list applies it; no date window. A type, level or part of the day this build does not know
    /// (a filter kept by a newer build) is left out: the panel could neither show it nor clear it.
    var filter: EventFilter {
        EventFilter(types: Set(types.filter { !$0.isUnknown }),
                    maxDistanceMeters: maxDistanceMeters,
                    minAttendees: minAttendees,
                    timesOfDay: Set(timesOfDay.compactMap(TimeOfDay.init(rawValue:))),
                    skillLevel: skillLevel?.ifKnown,
                    dateWindow: nil,
                    openSpotsOnly: openSpotsOnly)
    }
}
