import Foundation

/// What a user fills in to create or edit a group. Validated on device against the limits the backend enforces
/// (`AppConfig.Groups`, text lengths in UTF-16 units as the backend counts them), so a draft that passes never earns
/// a 400 for its lengths; the word filter and link policy stay the backend's (`contentRejected`).
nonisolated struct GroupDraft: Equatable, Sendable {
    /// Chosen once per draft and sent with every attempt: the backend uses it as the group id, so a create repeated
    /// after a lost answer finds its group instead of making a second one. Lower-case, as the backend stores it.
    let clientId: String
    var name = ""
    var description = ""
    var visibility: GroupVisibility = .public
    /// `nil` means any sport.
    var type: EventType?
    var membersCanCreateEvents = true
    var membersCanInvite = true

    init(clientId: String = UUID().uuidString.lowercased()) {
        self.clientId = clientId
    }

    /// The editable fields of an existing group, for the edit sheet; the id is the group's.
    init(editing group: SportGroup) {
        clientId = group.id
        name = group.name
        description = group.description ?? ""
        visibility = group.visibility
        type = group.type
        membersCanCreateEvents = group.membersCanCreateEvents
        membersCanInvite = group.membersCanInvite
    }

    /// One reason a draft cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case nameTooShort
        case nameTooLong
        case descriptionTooLong
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// `nil` when nothing was written, so the payload omits the field.
    var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Everything that keeps the draft from being sent; empty means it can go.
    var issues: [Issue] {
        var issues: [Issue] = []
        let limits = AppConfig.Groups.self
        if trimmedName.wireLength < limits.nameLength.lowerBound { issues.append(.nameTooShort) }
        if trimmedName.wireLength > limits.nameLength.upperBound { issues.append(.nameTooLong) }
        if trimmedDescription.wireLength > limits.descriptionMaxLength { issues.append(.descriptionTooLong) }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// The group this draft becomes once stored: the caller owns it and is its first member. What the mock
    /// repository and the test fake answer for a create; the backend builds the same shape from the payload.
    func makeGroup(ownerName: String, now: Date) -> SportGroup {
        SportGroup(id: clientId,
                   name: trimmedName,
                   description: trimmedDescription,
                   visibility: visibility,
                   type: type,
                   ownerName: ownerName,
                   memberCount: 1,
                   membersCanCreateEvents: membersCanCreateEvents,
                   membersCanInvite: membersCanInvite,
                   createdAt: now,
                   membership: GroupMembership(role: .owner, joinedAt: now))
    }
}
