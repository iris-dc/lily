import Foundation

/// Body of `PUT /api/groups/{id}`: the full editable set. Visibility is immutable and stays out; a missing `location`
/// clears the group's place, as the body is the whole state.
nonisolated struct UpdateGroupPayload: Encodable, Equatable, Sendable {
    let name: String
    let description: String?
    let type: EventType?
    let membersCanCreateEvents: Bool
    let membersCanInvite: Bool
    let location: CreateEventPayload.Location?

    init(draft: GroupDraft) {
        name = draft.trimmedName
        description = draft.trimmedDescription
        type = draft.type
        membersCanCreateEvents = draft.membersCanCreateEvents
        membersCanInvite = draft.membersCanInvite
        location = draft.location.map(CreateEventPayload.Location.init)
    }
}
