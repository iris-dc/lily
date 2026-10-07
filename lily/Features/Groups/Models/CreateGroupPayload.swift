import Foundation

/// Body of `POST /api/groups`: the backend's `CreateGroupRequest` key for key. A blank description, a missing type and
/// a group without a place are omitted, never sent as `null`.
nonisolated struct CreateGroupPayload: Encodable, Equatable, Sendable {
    let clientGroupId: String
    let name: String
    let description: String?
    let visibility: GroupVisibility
    let type: EventType?
    let membersCanCreateEvents: Bool
    let membersCanInvite: Bool
    /// The same shape as an event's place; absent when the draft names none.
    let location: CreateEventPayload.Location?

    init(draft: GroupDraft) {
        clientGroupId = draft.clientId
        name = draft.trimmedName
        description = draft.trimmedDescription
        visibility = draft.visibility
        type = draft.type
        membersCanCreateEvents = draft.membersCanCreateEvents
        membersCanInvite = draft.membersCanInvite
        location = draft.location.map(CreateEventPayload.Location.init)
    }
}
