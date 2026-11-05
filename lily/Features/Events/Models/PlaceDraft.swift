import Foundation

/// The place of a draft: the name typed and the spot picked. The event and tournament drafts judge it through the same
/// rule with their own requirement; `GroupDraft` (a private group may have none) and `MatchScheduleDraft` (no missing
/// rule, the venue as fallback) keep rules of their own and are not built on it.
nonisolated struct PlaceDraft: Equatable, Sendable {
    var name: String
    var coordinate: Coordinate?

    /// What of the place must be there: both halves (a tournament), or either (an event, whose missing half the
    /// geocoder fills on submit).
    enum Requirement: Sendable {
        case nameAndSpot
        case nameOrSpot
    }

    /// One reason the place cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case nameMissing
        case nameTooLong
        case coordinateMissing
        /// Neither a name nor a spot, where either would do.
        case placeMissing
    }

    var trimmedName: String { name.trimmed }

    /// In form order: what is missing under `requiring`, then a name over `maxLength` UTF-16 units (`wireLength`, the
    /// backend's count).
    func issues(maxLength: Int, requiring requirement: Requirement = .nameAndSpot) -> [Issue] {
        var issues = missing(under: requirement)
        if trimmedName.wireLength > maxLength { issues.append(.nameTooLong) }
        return issues
    }

    private func missing(under requirement: Requirement) -> [Issue] {
        switch requirement {
        case .nameAndSpot:
            var issues: [Issue] = []
            if trimmedName.isEmpty { issues.append(.nameMissing) }
            if coordinate == nil { issues.append(.coordinateMissing) }
            return issues
        case .nameOrSpot:
            return trimmedName.isEmpty && coordinate == nil ? [.placeMissing] : []
        }
    }

    /// The stored location: the trimmed name at `coordinate`, which the caller resolves (a create's proposed spot, an
    /// edit's own or the current one).
    func location(at coordinate: Coordinate) -> EventLocation {
        EventLocation(name: trimmedName, coordinate: coordinate)
    }
}
