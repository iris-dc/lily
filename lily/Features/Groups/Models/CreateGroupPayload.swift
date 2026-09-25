import Foundation

/// Body of `POST /api/groups`: the backend's `CreateGroupRequest` key for key. A blank description and a missing type
/// are omitted, never sent as `null`.
nonisolated struct CreateGroupPayload: Encodable, Equatable, Sendable {
    let clientGroupId: String
    let name: String
    let description: String?
    let visibility: GroupVisibility
    let type: EventType?
    let membersCanCreateEvents: Bool
    let membersCanInvite: Bool

    init(draft: GroupDraft) {
        clientGroupId = draft.clientId
        name = draft.trimmedName
        description = draft.trimmedDescription
        visibility = draft.visibility
        type = draft.type
        membersCanCreateEvents = draft.membersCanCreateEvents
        membersCanInvite = draft.membersCanInvite
    }
}
