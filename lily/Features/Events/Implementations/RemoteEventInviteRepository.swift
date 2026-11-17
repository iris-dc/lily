import Foundation

/// Invites into an event from the Laurel backend, behind the invite seam the group sheet already uses: the routes are
/// the event's, keyed by its id (its room shares it). Both fall back to `.inviteUnavailable`; `ALREADY_JOINED` and
/// `FORBIDDEN` are about the invitee and the inviter here, `INVITE_LIMIT` is the event's own cap, and `EVENT_STARTED`
/// passes through as the typed refusal it is.
final class RemoteEventInviteRepository: InviteRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// The candidates come as `{items: [InviteCandidate]}` in the group invitee shape, the participants already excluded.
    func candidates(groupID eventID: String) async throws -> [InviteCandidate] {
        let request = APIRequest<Page<InviteCandidate>>.get(AppConfig.API.Paths.eventInvitees(id: eventID))
        return try await send(request).items
    }

    func invite(groupID eventID: String, userID: String) async throws -> SentInvite {
        let request = APIRequest<SentInvite>.post(AppConfig.API.Paths.eventInvites(id: eventID),
                                                  body: SendInvitePayload(userId: userID))
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        do {
            return try await client.send(request, failingWith: .inviteUnavailable)
        } catch let error as AppError {
            throw error.asEventInviteRefusal
        }
    }
}

private extension AppError {
    /// On an invite, the join codes speak of the other person and of the caller's right to invite, and the shared
    /// `INVITE_LIMIT` mapping of the event's own cap.
    var asEventInviteRefusal: AppError {
        switch self {
        case .alreadyJoined: .inviteeAlreadyJoined
        case .insufficientRole: .cannotInviteToEvent
        case .tournamentInviteLimit: .eventInviteLimit
        default: self
        }
    }
}
