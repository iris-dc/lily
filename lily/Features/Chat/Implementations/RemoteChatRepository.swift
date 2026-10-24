import Foundation

/// Chat from the Laurel backend (plan section 3.4). Reads, the read marker and the clear fall back to
/// `.chatUnavailable`, a send to `.messageSendFailed`, an upload ticket to `.attachmentUploadFailed` and a link
/// refresh to `.attachmentUnavailable`, a vote to `.voteFailed` and a pin to `.pinFailed`; the codes with copy of their own
/// map through the shared `BackendErrorCode`.
final class RemoteChatRepository: ChatRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func newest(groupID: String) async throws -> MessagePage {
        try await page(groupID: groupID, query: [limit(AppConfig.Chat.historyPageSize)])
    }

    func older(groupID: String, before messageID: String) async throws -> MessagePage {
        let cursor = URLQueryItem(name: AppConfig.API.Query.before, value: messageID)
        return try await page(groupID: groupID, query: [cursor, limit(AppConfig.Chat.historyPageSize)])
    }

    func newer(groupID: String, after messageID: String) async throws -> MessagePage {
        let cursor = URLQueryItem(name: AppConfig.API.Query.after, value: messageID)
        return try await page(groupID: groupID, query: [cursor, limit(AppConfig.Chat.catchUpPageSize)])
    }

    func send(groupID: String, _ draft: MessageDraft) async throws -> SentMessage {
        let request = APIRequest<SentMessage>.post(AppConfig.API.Paths.messages(id: groupID), body: draft.payload)
        return try await client.send(request, failingWith: .messageSendFailed)
    }

    func delete(groupID: String, messageID: String) async throws -> ChatMessage {
        let request = APIRequest<ChatMessage>.delete(AppConfig.API.Paths.message(id: groupID, messageID: messageID))
        return try await client.send(request, failingWith: .chatUnavailable)
    }

    func markRead(groupID: String, messageID: String) async throws -> ReadMarker {
        let request = APIRequest<ReadMarker>.put(AppConfig.API.Paths.read(id: groupID),
                                                 body: ReadMarkerPayload(messageId: messageID))
        return try await client.send(request, failingWith: .chatUnavailable)
    }

    func clearHistory(groupID: String) async throws -> ClearedHistory {
        let request = APIRequest<ClearedHistory>.delete(AppConfig.API.Paths.messages(id: groupID))
        return try await client.send(request, failingWith: .chatUnavailable)
    }

    func requestUpload(groupID: String, _ request: UploadRequestPayload) async throws -> UploadTicket {
        let call = APIRequest<UploadTicket>.post(AppConfig.API.Paths.uploads(id: groupID), body: request)
        return try await client.send(call, failingWith: .attachmentUploadFailed)
    }

    func refreshAttachment(groupID: String, messageID: String, attachmentID: String) async throws -> AttachmentLink {
        let path = AppConfig.API.Paths.attachment(id: groupID, messageID: messageID, attachmentID: attachmentID)
        return try await client.send(.get(path), failingWith: .attachmentUnavailable)
    }

    func vote(groupID: String, messageID: String, optionIDs: [String]) async throws -> VoteResult {
        let request = APIRequest<VoteResult>.put(AppConfig.API.Paths.vote(id: groupID, messageID: messageID),
                                                 body: VotePayload(optionIds: optionIDs))
        return try await client.send(request, failingWith: .voteFailed)
    }

    func polls(groupID: String, messageIDs: [String]) async throws -> PollStates {
        let ids = URLQueryItem(name: AppConfig.API.Query.ids, value: messageIDs.joined(separator: ","))
        return try await client.send(.get(AppConfig.API.Paths.polls(id: groupID), query: [ids]), failingWith: .chatUnavailable)
    }

    func voters(groupID: String, messageID: String) async throws -> PollVoters {
        try await client.send(.get(AppConfig.API.Paths.voters(id: groupID, messageID: messageID)), failingWith: .chatUnavailable)
    }

    func pin(groupID: String, messageID: String) async throws -> PinList {
        let request = APIRequest<PinList>.put(AppConfig.API.Paths.pin(id: groupID, messageID: messageID))
        return try await client.send(request, failingWith: .pinFailed)
    }

    func unpin(groupID: String, messageID: String) async throws -> PinList {
        let request = APIRequest<PinList>.delete(AppConfig.API.Paths.pin(id: groupID, messageID: messageID))
        return try await client.send(request, failingWith: .pinFailed)
    }

    private func page(groupID: String, query: [URLQueryItem]) async throws -> MessagePage {
        try await client.send(.get(AppConfig.API.Paths.messages(id: groupID), query: query), failingWith: .chatUnavailable)
    }

    private func limit(_ count: Int) -> URLQueryItem {
        URLQueryItem(name: AppConfig.API.Query.limit, value: String(count))
    }
}
