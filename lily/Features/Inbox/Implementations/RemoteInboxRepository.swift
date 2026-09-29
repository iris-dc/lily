import Foundation

/// The inbox from the Laurel backend (inbox plan section 2.2). Reads and the read marker fall back to
/// `.inboxUnavailable`, accept and decline to `.inviteActionFailed`; the codes with copy of their own map through the
/// shared `BackendErrorCode`.
final class RemoteInboxRepository: InboxRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func page(before itemID: String?, limit: Int) async throws -> InboxPage {
        var query: [URLQueryItem] = []
        if let itemID { query.append(URLQueryItem(name: AppConfig.API.Query.before, value: itemID)) }
        query.append(URLQueryItem(name: AppConfig.API.Query.limit, value: String(limit)))
        return try await client.send(.get(AppConfig.API.Paths.inbox, query: query), failingWith: .inboxUnavailable)
    }

    func markRead(itemID: String) async throws -> String {
        let request = APIRequest<InboxReadMarker>.put(AppConfig.API.Paths.inboxRead, body: InboxReadPayload(itemId: itemID))
        return try await client.send(request, failingWith: .inboxUnavailable).lastReadId
    }

    func accept(itemID: String) async throws -> InviteAcceptance {
        let request = APIRequest<InviteAcceptance>.post(AppConfig.API.Paths.inboxAccept(id: itemID))
        return try await client.send(request, failingWith: .inviteActionFailed)
    }

    func decline(itemID: String) async throws -> InboxItem {
        let request = APIRequest<InviteDeclination>.post(AppConfig.API.Paths.inboxDecline(id: itemID))
        return try await client.send(request, failingWith: .inviteActionFailed).item
    }
}
