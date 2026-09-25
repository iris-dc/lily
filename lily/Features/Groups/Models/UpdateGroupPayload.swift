import Foundation

/// Body of `PUT /api/groups/{id}`: the full editable set. Visibility is immutable and stays out.
nonisolated struct UpdateGroupPayload: Encodable, Equatable, Sendable {
    let name: String
    let description: String?
    let type: EventType?
    let membersCanCreateEvents: Bool
    let membersCanInvite: Bool

    init(draft: GroupDraft) {
        name = draft.trimmedName
        description = draft.trimmedDescription
        type = draft.type
        membersCanCreateEvents = draft.membersCanCreateEvents
        membersCanInvite = draft.membersCanInvite
    }
}
