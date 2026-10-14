import Foundation

/// The place of a draft: the name typed and the spot picked. The event and tournament drafts judge it alike; `GroupDraft`
/// (a private group may have none) and `MatchScheduleDraft` (no missing rule, the venue as fallback) keep rules of their
/// own and are not built on it.
nonisolated struct PlaceDraft: Equatable, Sendable {
    var name: String
    var coordinate: Coordinate?

    /// One reason the place cannot be sent, in the order the form shows its fields.
    enum Issue: Hashable, Sendable {
        case nameMissing
        case nameTooLong
        case coordinateMissing
    }

    var trimmedName: String { name.trimmed }

    /// In form order: no name, a name over `maxLength` UTF-16 units (`wireLength`, the backend's count), no spot.
    func issues(maxLength: Int) -> [Issue] {
        var issues: [Issue] = []
        if trimmedName.isEmpty { issues.append(.nameMissing) }
        if trimmedName.wireLength > maxLength { issues.append(.nameTooLong) }
        if coordinate == nil { issues.append(.coordinateMissing) }
        return issues
    }

    /// The stored location: the trimmed name at `coordinate`, which the caller resolves (a create's proposed spot, an
    /// edit's own or the current one).
    func location(at coordinate: Coordinate) -> EventLocation {
        EventLocation(name: trimmedName, coordinate: coordinate)
    }
}
