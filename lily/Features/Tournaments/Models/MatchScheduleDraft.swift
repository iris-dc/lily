import Foundation

/// The organiser's schedule form: the time, the place name and the picked spot, opened from `MatchSchedule.proposal`
/// and turned back into the `MatchSchedule` to send. A named place stands at the picked spot, or at the tournament's
/// venue when none was picked; an empty name sends the time alone. Pure, so the rules are tested without the view.
nonisolated struct MatchScheduleDraft: Equatable, Sendable {
    var scheduledAt: Date
    var locationName: String
    var coordinate: Coordinate?
    /// The earliest time the picker offers: now, or the match's own earlier time, so a past schedule still shows.
    let earliest: Date

    init(proposal: MatchSchedule, now: Date) {
        let proposed = proposal.scheduledAt ?? now
        scheduledAt = proposed
        locationName = proposal.location?.name ?? ""
        coordinate = proposal.location?.coordinate
        earliest = min(now, proposed)
    }

    var trimmedLocationName: String { locationName.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The place name within the backend's limit; everything else is always sendable.
    var isValid: Bool { trimmedLocationName.wireLength <= AppConfig.Events.Creation.locationNameMaxLength }

    /// The place, when named: the typed name at the picked spot, else at `venue`; `nil` without a name or a spot.
    func location(venue: Coordinate?) -> EventLocation? {
        guard !trimmedLocationName.isEmpty, let coordinate = coordinate ?? venue else { return nil }
        return EventLocation(name: trimmedLocationName, coordinate: coordinate)
    }

    func schedule(venue: Coordinate?) -> MatchSchedule {
        MatchSchedule(scheduledAt: scheduledAt, location: location(venue: venue))
    }
}
