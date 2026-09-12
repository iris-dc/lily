import Foundation

/// Body of `POST /api/events`: the backend's `CreateEventRequest` key for key. Blank optional details are omitted,
/// never sent as `null`, and a free game sends no price at all.
nonisolated struct CreateEventPayload: Encodable, Equatable, Sendable {
    struct Location: Encodable, Equatable, Sendable {
        let name: String
        let coordinate: Coordinate
    }

    let clientEventId: String
    let title: String
    let type: EventType
    let startsAt: Date
    let location: Location
    let capacity: Int
    let description: String?
    let lookingFor: String?
    let skillLevel: SkillLevel?
    let price: Price?

    /// `nil` when the draft has no coordinate yet; callers validate the draft first.
    init?(draft: EventDraft, currencyCode: String = AppConfig.Events.marketCurrencyCode) {
        guard let coordinate = draft.coordinate else { return nil }
        clientEventId = draft.clientId
        title = draft.trimmedTitle
        type = draft.type
        startsAt = draft.startsAt
        location = Location(name: draft.trimmedLocationName, coordinate: coordinate)
        capacity = draft.capacity
        description = draft.trimmedDescription
        lookingFor = draft.trimmedLookingFor
        skillLevel = draft.skillLevel
        price = draft.price(currencyCode: currencyCode)
    }
}
