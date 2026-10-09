import Foundation

/// Body of `POST /api/events`: the backend's `CreateEventRequest` key for key. Blank optional details are omitted,
/// never sent as `null`, and a free game sends no price at all.
nonisolated struct CreateEventPayload: Encodable, Equatable, Sendable {
    struct Location: Encodable, Equatable, Sendable {
        let name: String
        let coordinate: Coordinate

        init(name: String, coordinate: Coordinate) {
            self.name = name
            self.coordinate = coordinate
        }

        /// A stored place as a payload's, for the group bodies that send one.
        init(_ location: EventLocation) {
            self.init(name: location.name, coordinate: location.coordinate)
        }
    }

    let clientEventId: String
    let title: String
    let type: EventType
    let startsAt: Date
    let location: Location
    /// Omitted for a game without a limit.
    let capacity: Int?
    let allowsExtraParticipants: Bool
    let description: String?
    let lookingFor: String?
    let skillLevel: SkillLevel?
    let price: Price?
    /// Omitted for a game of its own; the backend checks the caller may create games in the group.
    let groupId: String?

    /// `nil` when the draft has no coordinate yet; callers validate the draft first.
    init?(draft: EventDraft) {
        guard let coordinate = draft.coordinate else { return nil }
        clientEventId = draft.clientId
        title = draft.trimmedTitle
        type = draft.type
        startsAt = draft.startsAt
        location = Location(name: draft.trimmedLocationName, coordinate: coordinate)
        capacity = draft.capacityIfLimited
        allowsExtraParticipants = draft.allowsExtraParticipants
        description = draft.trimmedDescription
        lookingFor = draft.trimmedLookingFor
        skillLevel = draft.skillLevel
        price = draft.eventPrice
        groupId = draft.group?.id
    }
}
