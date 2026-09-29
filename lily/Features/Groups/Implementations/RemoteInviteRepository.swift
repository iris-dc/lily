import Foundation

/// Direct invites from the Laurel backend (inbox plan, section 2.2). Both routes fall back to `.inviteUnavailable`;
/// the codes with copy of their own (`ALREADY_MEMBER`, `CANNOT_INVITE`, `USER_NOT_FOUND`, ...) map through the shared
/// `BackendErrorCode`.
final class RemoteInviteRepository: InviteRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// The candidates come as `{items: [InviteCandidate]}` without a cursor.
    func candidates(groupID: String) async throws -> [InviteCandidate] {
        let request = APIRequest<Page<InviteCandidate>>.get(AppConfig.API.Paths.groupInvitees(id: groupID))
        return try await client.send(request, failingWith: .inviteUnavailable).items
    }

    func invite(groupID: String, userID: String) async throws -> SentInvite {
        let request = APIRequest<SentInvite>.post(AppConfig.API.Paths.groupInvites(id: groupID),
                                                  body: SendInvitePayload(userId: userID))
        return try await client.send(request, failingWith: .inviteUnavailable)
    }
}
