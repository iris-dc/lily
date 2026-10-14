import Foundation

/// The Discover side of the group mock: which stored groups a browse or a search answers, and in which order, as the
/// backend decides them.
extension MockGroupRepository {
    /// The public communities matching `prefix` (the trimmed search, `nil` for a browse) and `type`, in the backend's
    /// order for the request.
    func discover(prefix: String?, type: EventType?, near position: Coordinate?) -> Page<SportGroup> {
        // Like the backend: only communities are discoverable; rooms are reached through their tournament or person.
        let matching = groups.filter {
            !$0.isDeleted && $0.isCommunity && $0.isPublic && $0.matches(prefix: prefix, type: type)
        }
        return Page(items: Self.discoverOrder(matching, prefix: prefix, near: position))
    }

    /// The backend's three Discover orders: by name for a search, nearest first around a position (a group without a
    /// place last), newest first otherwise.
    private static func discoverOrder(_ groups: [SportGroup], prefix: String?, near position: Coordinate?) -> [SportGroup] {
        if prefix != nil {
            return groups.sorted { $0.name < $1.name }
        }
        guard let position else {
            return groups.sorted { $0.createdAt > $1.createdAt }
        }
        return groups.sorted { lhs, rhs in
            switch (lhs.distance(from: position), rhs.distance(from: position)) {
            case (let left?, let right?): left < right
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): lhs.createdAt > rhs.createdAt
            }
        }
    }
}

private extension SportGroup {
    /// Discover's criteria: a name prefix, case-insensitively, and the event type.
    func matches(prefix: String?, type: EventType?) -> Bool {
        let nameMatches = prefix.map { name.lowercased().hasPrefix($0.lowercased()) } ?? true
        let typeMatches = type.map { $0 == self.type } ?? true
        return nameMatches && typeMatches
    }
}
