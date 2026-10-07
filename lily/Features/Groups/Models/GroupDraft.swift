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
    /// Where the group plays. A public group needs one (Discover orders by it); a private group may leave it out.
    var locationName = ""
    /// Prefilled from the device's position when the sheet opens, else set on the map.
    var coordinate: Coordinate?

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
        locationName = group.location?.name ?? ""
        coordinate = group.location?.coordinate
    }

    /// One reason a draft cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case nameTooShort
        case nameTooLong
        case descriptionTooLong
        /// A public group without a place; a private one may have none.
        case locationNameMissing
        case locationNameTooLong
        /// A place was named but its spot not set (the device had no position and the map was never opened).
        case coordinateMissing
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedLocationName: String { locationName.trimmingCharacters(in: .whitespacesAndNewlines) }
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
        issues += locationIssues
        return issues
    }

    /// The place is judged like the event form's, except that only a public group must have one: a private group is
    /// reached by invite, a public one is found by where it plays.
    private var locationIssues: [Issue] {
        var issues: [Issue] = []
        if trimmedLocationName.isEmpty {
            if visibility == .public { issues.append(.locationNameMissing) }
            return issues
        }
        if trimmedLocationName.wireLength > AppConfig.Groups.locationNameMaxLength { issues.append(.locationNameTooLong) }
        if coordinate == nil { issues.append(.coordinateMissing) }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// The place as the payload and the stored group carry it; `nil` when none was named or its spot is not set.
    var location: EventLocation? {
        guard !trimmedLocationName.isEmpty, let coordinate else { return nil }
        return EventLocation(name: trimmedLocationName, coordinate: coordinate)
    }

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
                   membership: GroupMembership(role: .owner, joinedAt: now),
                   location: location)
    }
}
