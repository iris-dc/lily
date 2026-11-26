import Foundation

/// Which events a list shows out of the ones it loaded, judged on device. The default already limits distance to
/// `AppConfig.Events.defaultFilterRadiusMeters` around the user's position.
nonisolated struct EventFilter: Hashable, Sendable {
    var types: Set<EventType> = []
    /// Radius around the reference point; `nil` means anywhere.
    var maxDistanceMeters: Double? = AppConfig.Events.defaultFilterRadiusMeters
    /// At least this many people already in; `nil` means any number.
    var minAttendees: Int?
    /// Parts of the day the game may start in; empty means any time.
    var timesOfDay: Set<TimeOfDay> = []
    /// `nil` means any level. Games that welcome any level (no `skillLevel`, or one this build does not know) match
    /// every choice.
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
        matchesType(event) && matchesDistance(event, from: origin) && matchesAttendees(event)
            && matchesTime(event) && matchesLevel(event) && matchesDate(event) && (!openSpotsOnly || !event.isFull)
    }

    /// Adds the type to the selection, or removes it when it is already selected.
    mutating func toggle(_ type: EventType) {
        if types.remove(type) == nil { types.insert(type) }
    }

    /// Adds the part of the day to the selection, or removes it when it is already selected.
    mutating func toggle(_ time: TimeOfDay) {
        if timesOfDay.remove(time) == nil { timesOfDay.insert(time) }
    }

    mutating func clear() { self = EventFilter() }

    private func matchesType(_ event: SportEvent) -> Bool {
        types.isEmpty || types.contains(event.type)
    }

    private func matchesDistance(_ event: SportEvent, from origin: Coordinate?) -> Bool {
        guard let maxDistanceMeters, let origin else { return true }
        return event.location.coordinate.distance(to: origin) <= maxDistanceMeters
    }

    private func matchesAttendees(_ event: SportEvent) -> Bool {
        guard let minAttendees else { return true }
        return event.participantCount >= minAttendees
    }

    private func matchesTime(_ event: SportEvent) -> Bool {
        timesOfDay.isEmpty || timesOfDay.contains(.of(event.startsAt))
    }

    private func matchesLevel(_ event: SportEvent) -> Bool {
        guard let skillLevel, let eventLevel = event.skillLevel?.ifKnown else { return true }
        return eventLevel == skillLevel
    }

    private func matchesDate(_ event: SportEvent) -> Bool {
        dateWindow?.contains(event.startsAt) ?? true
    }
}
