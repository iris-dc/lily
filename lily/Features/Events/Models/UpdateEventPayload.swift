import Foundation

/// Body of `PUT /api/events/{id}`: the backend's `UpdateEventRequest` key for key, which is the create body without the
/// id and the group (neither can change). Blank optional details are omitted, so the backend removes them, and a free
/// game sends no price at all.
nonisolated struct UpdateEventPayload: Encodable, Equatable, Sendable {
    let title: String
    let type: EventType
    let startsAt: Date
    let location: CreateEventPayload.Location
    /// Omitted for a game without a limit, which the backend reads as lifting one.
    let capacity: Int?
    let allowsExtraParticipants: Bool
    let description: String?
    let lookingFor: String?
    let skillLevel: SkillLevel?
    let price: Price?

    /// `nil` when the draft has no coordinate; a draft made from an event always has one.
    init?(draft: EventDraft) {
        guard let coordinate = draft.coordinate else { return nil }
        title = draft.trimmedTitle
        type = draft.type
        startsAt = draft.startsAt
        location = CreateEventPayload.Location(name: draft.trimmedLocationName, coordinate: coordinate)
        capacity = draft.capacityIfLimited
        allowsExtraParticipants = draft.allowsExtraParticipants
        description = draft.trimmedDescription
        lookingFor = draft.trimmedLookingFor
        skillLevel = draft.skillLevel
        price = draft.eventPrice
    }
}
