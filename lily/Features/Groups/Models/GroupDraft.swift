import Foundation

/// What a user fills in to create or edit a group. Validated on device against the limits the backend enforces
/// (`AppConfig.Groups`, text lengths in UTF-16 units as the backend counts them), so a draft that passes never earns
/// a 400 for its lengths; the word filter and link policy stay the backend's (`contentRejected`).
nonisolated struct GroupDraft: Equatable, Sendable, PlacePickingDraft {
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
    /// The optional second line of the address (apartment, floor, entrance), appended to the stored name on the wire
    /// (`composedLocationName`); it never affects whether the place is there.
    var locationDetail = ""
    /// Prefilled from the device's position when the sheet opens, else set on the map.
    var coordinate: Coordinate?
    /// Whether the user chose `coordinate` on the map (or edits a stored group): a chosen spot is the user's own,
    /// never prepare's proposal (`PlacePickingDraft`; the wizard's dirty rule reads it).
    var spotPickedOnMap = false
    /// The name whose suggestion produced `coordinate` (`PlacePickingDraft`); never on the wire.
    var suggestedName: String?

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
        // A stored name that carries an old detail suffix stays the address whole; the detail line starts empty.
        locationName = group.location?.name ?? ""
        coordinate = group.location?.coordinate
        // The stored spot is the owner's choice: an edited name alone must not move the group on the map.
        spotPickedOnMap = true
    }

    /// One reason a draft cannot be sent, in the order the form shows its fields.
    enum Issue: CaseIterable, Hashable, Sendable {
        case nameTooShort
        case nameTooLong
        case descriptionTooLong
        /// A public group without a place; a private one may have none.
        case locationNameMissing
        case locationNameTooLong
        /// A place was named but its spot not set (the device had no position and the map was never opened).
        case coordinateMissing
        /// A typed name that was never chosen: no tapped suggestion still naming the field and no spot set on the
        /// map. Free text alone creates nothing (round 5).
        case placeNotChosen
    }

    var trimmedName: String { name.trimmed }
    var trimmedLocationName: String { locationName.trimmed }
    /// `nil` when nothing was written, so the payload omits the field.
    var trimmedDescription: String? { description.nonBlankTrimmed }

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
    /// reached by invite, a public one is found by where it plays. A place being provided must really be chosen —
    /// a tapped suggestion or a spot set on the map — so free text alone sends nothing (round 5).
    private var locationIssues: [Issue] {
        if trimmedLocationName.isEmpty {
            return visibility == .public ? [.locationNameMissing] : []
        }
        var issues: [Issue] = []
        if composedLocationName.wireLength > AppConfig.Groups.locationNameMaxLength { issues.append(.locationNameTooLong) }
        if !placeChosen {
            issues.append(.placeNotChosen)
        } else if coordinate == nil {
            issues.append(.coordinateMissing)
        }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// The place as the payload and the stored group carry it (the composed name: the address plus the detail
    /// line); `nil` when none was named or its spot is not set.
    var location: EventLocation? {
        guard !trimmedLocationName.isEmpty, let coordinate else { return nil }
        return EventLocation(name: composedLocationName, coordinate: coordinate)
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
