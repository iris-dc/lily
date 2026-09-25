import Foundation

/// Invites from the Laurel backend. The code goes into a JSON body on preview and redeem; the API client logs only
/// method and path, so a code can never end up in a log line.
final class RemoteInviteRepository: InviteRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func create(groupID: String, options: InviteOptions) async throws -> Invite {
        let request = APIRequest<Invite>.post(AppConfig.API.Paths.groupInvites(id: groupID), body: options)
        return try await client.send(request, failingWith: .groupActionFailed)
    }

    func list(groupID: String) async throws -> [Invite] {
        let page: Page<Invite> = try await client.send(.get(AppConfig.API.Paths.groupInvites(id: groupID)),
                                                       failingWith: .groupsUnavailable)
        return page.items
    }

    func revoke(groupID: String, inviteID: String) async throws -> Invite {
        let path = AppConfig.API.Paths.groupInvite(id: groupID, inviteID: inviteID)
        return try await client.send(.delete(path), failingWith: .groupActionFailed)
    }

    func preview(code: InviteCode) async throws -> InvitePreview {
        let request = APIRequest<InvitePreview>.post(AppConfig.API.Paths.invitePreview, body: InviteCodePayload(code))
        return try await client.send(request, failingWith: .inviteInvalid)
    }

    func redeem(code: InviteCode) async throws -> SportGroup {
        let request = APIRequest<SportGroup>.post(AppConfig.API.Paths.inviteRedeem, body: InviteCodePayload(code))
        return try await client.send(request, failingWith: .groupActionFailed)
    }
}
