import Foundation

/// Which events a list shows out of the ones it loaded. Together the criteria narrow the loaded page on device; the
/// backend will take the same criteria as query parameters later. The default already limits distance to
/// `AppConfig.Events.defaultFilterRadiusMeters` around the reference point (the user's position for now).
nonisolated struct EventFilter: Hashable, Sendable {
    var types: Set<EventType> = []
    /// Radius around the reference point; `nil` means anywhere.
    var maxDistanceMeters: Double? = AppConfig.Events.defaultFilterRadiusMeters
    /// Per-person price cap in the market currency; `nil` means any price, zero means free games only.
    var maxPrice: Decimal?
    /// `nil` means any level. Games that welcome any level (no `skillLevel` of their own) match every choice.
    var skillLevel: SkillLevel?
    /// Days the game must start on; `nil` means any time.
    var dateWindow: DateWindow?
    var openSpotsOnly = false

    /// No criterion at all, not even the default radius: what a list that has no filter button should show.
    static let everything = EventFilter(maxDistanceMeters: nil)

    var isActive: Bool { self != EventFilter() }

    func includes(_ type: EventType) -> Bool { types.contains(type) }

    /// `origin` is the reference point for the distance criterion. Without one (location denied or not yet known)
    /// distance cannot be judged, so that criterion is skipped rather than hiding every event.
    func matches(_ event: SportEvent, from origin: Coordinate?) -> Bool {
        matchesType(event) && matchesDistance(event, from: origin) && matchesPrice(event)
            && matchesLevel(event) && matchesDate(event) && (!openSpotsOnly || !event.isFull)
    }

    /// Adds the type to the selection, or removes it when it is already selected.
    mutating func toggle(_ type: EventType) {
        if types.remove(type) == nil { types.insert(type) }
    }

    mutating func clear() { self = EventFilter() }

    private func matchesType(_ event: SportEvent) -> Bool {
        types.isEmpty || types.contains(event.type)
    }

    private func matchesDistance(_ event: SportEvent, from origin: Coordinate?) -> Bool {
        guard let maxDistanceMeters, let origin else { return true }
        return event.location.coordinate.distance(to: origin) <= maxDistanceMeters
    }

    /// Amounts are compared without currency conversion: one currency per market for now.
    private func matchesPrice(_ event: SportEvent) -> Bool {
        guard let maxPrice else { return true }
        return (event.price?.amount ?? 0) <= maxPrice
    }

    private func matchesLevel(_ event: SportEvent) -> Bool {
        guard let skillLevel else { return true }
        return event.skillLevel == nil || event.skillLevel == skillLevel
    }

    private func matchesDate(_ event: SportEvent) -> Bool {
        dateWindow?.contains(event.startsAt) ?? true
    }
}
