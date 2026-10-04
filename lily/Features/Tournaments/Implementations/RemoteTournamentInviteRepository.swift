import Foundation

/// Invites into a tournament from the Laurel backend, behind the invite seam the group sheet already uses: the routes
/// are the tournament's, keyed by its id (its room shares it). Both fall back to `.inviteUnavailable`; `ALREADY_ENTERED`
/// and `FORBIDDEN` are about the invitee and the inviter here, so they are re-read as the invite refusals.
final class RemoteTournamentInviteRepository: InviteRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// The candidates come as `{items: [InviteCandidate]}` in the group invitee shape, the entrants already excluded.
    func candidates(groupID tournamentID: String) async throws -> [InviteCandidate] {
        let request = APIRequest<Page<InviteCandidate>>.get(AppConfig.API.Paths.tournamentInvitees(id: tournamentID))
        return try await send(request).items
    }

    func invite(groupID tournamentID: String, userID: String) async throws -> SentInvite {
        let request = APIRequest<SentInvite>.post(AppConfig.API.Paths.tournamentInvites(id: tournamentID),
                                                  body: SendInvitePayload(userId: userID))
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        do {
            return try await client.send(request, failingWith: .inviteUnavailable)
        } catch let error as AppError {
            throw error.asTournamentInviteRefusal
        }
    }
}

private extension AppError {
    /// On an invite, the entry codes speak of the other person and of the caller's right to invite.
    var asTournamentInviteRefusal: AppError {
        switch self {
        case .alreadyEntered: .inviteeAlreadyEntered
        case .insufficientRole: .cannotInviteToTournament
        default: self
        }
    }
}
