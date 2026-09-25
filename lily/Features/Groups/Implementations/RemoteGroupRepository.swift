import Foundation

/// Groups from the Laurel backend. Leaving is `DELETE .../members/<own id>`, so the repository needs the caller's id.
final class RemoteGroupRepository: GroupRepository {
    private let client: any APIClient
    private let identity: any IdentityProvider

    init(client: any APIClient, identity: any IdentityProvider) {
        self.client = client
        self.identity = identity
    }

    func groups(in scope: GroupScope, cursor: String?) async throws -> Page<SportGroup> {
        var query = scope.queryItems
        if let cursor {
            query.append(URLQueryItem(name: AppConfig.API.Query.cursor, value: cursor))
        }
        return try await client.send(.get(AppConfig.API.Paths.groups, query: query), failingWith: .groupsUnavailable)
    }

    func group(id: String) async throws -> SportGroup {
        try await client.send(.get(AppConfig.API.Paths.group(id: id)), failingWith: .groupsUnavailable)
    }

    func create(_ draft: GroupDraft) async throws -> SportGroup {
        let request = APIRequest<SportGroup>.post(AppConfig.API.Paths.groups, body: CreateGroupPayload(draft: draft))
        return try await client.send(request, failingWith: .groupCreationFailed)
    }

    func update(id: String, _ draft: GroupDraft) async throws -> SportGroup {
        let request = APIRequest<SportGroup>.put(AppConfig.API.Paths.group(id: id), body: UpdateGroupPayload(draft: draft))
        return try await client.send(request, failingWith: .groupActionFailed)
    }

    func delete(id: String) async throws -> SportGroup {
        try await client.send(.delete(AppConfig.API.Paths.group(id: id)), failingWith: .groupActionFailed)
    }

    func join(id: String) async throws -> SportGroup {
        try await client.send(.post(AppConfig.API.Paths.groupMembers(id: id)), failingWith: .groupActionFailed)
    }

    /// A guest has no row to delete; the screens never offer Leave to one, so this is a safety net, not a state.
    func leave(id: String) async throws -> SportGroup {
        guard let userID = identity.currentUserID else { throw AppError.notAMember }
        return try await remove(id: id, userID: userID)
    }

    func remove(id: String, userID: String) async throws -> SportGroup {
        let path = AppConfig.API.Paths.groupMember(id: id, userID: userID)
        return try await client.send(.delete(path), failingWith: .groupActionFailed)
    }

    func setRole(id: String, userID: String, _ role: MemberRole) async throws -> GroupMember {
        let request = APIRequest<GroupMember>.put(AppConfig.API.Paths.groupMember(id: id, userID: userID),
                                                  body: RoleChangePayload(role: role))
        return try await client.send(request, failingWith: .groupActionFailed)
    }

    func members(id: String) async throws -> [GroupMember] {
        try await roster(at: AppConfig.API.Paths.groupMembers(id: id))
    }

    func bans(id: String) async throws -> [GroupMember] {
        try await roster(at: AppConfig.API.Paths.groupBans(id: id))
    }

    func unban(id: String, userID: String) async throws {
        let request = APIRequest<UnbanReceipt>.delete(AppConfig.API.Paths.groupBan(id: id, userID: userID))
        _ = try await client.send(request, failingWith: .groupActionFailed)
    }

    /// Both rosters come as `{items: [Member]}` without a cursor.
    private func roster(at path: String) async throws -> [GroupMember] {
        let page: Page<GroupMember> = try await client.send(.get(path), failingWith: .groupsUnavailable)
        return page.items
    }
}

private extension GroupScope {
    /// The `scope` parameter and, for Discover, the optional criteria and the page size.
    var queryItems: [URLQueryItem] {
        let keys = AppConfig.API.Query.self
        switch self {
        case .mine:
            return [URLQueryItem(name: keys.scope, value: "mine")]
        case .discover(let query, let type):
            var items = [URLQueryItem(name: keys.scope, value: "public")]
            if let query, !query.isEmpty {
                items.append(URLQueryItem(name: keys.query, value: query))
            }
            if let type {
                items.append(URLQueryItem(name: keys.type, value: type.rawValue))
            }
            items.append(URLQueryItem(name: keys.limit, value: String(AppConfig.Groups.discoverPageSize)))
            return items
        }
    }
}
