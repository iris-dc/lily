import Foundation

/// Chat without a backend: fixture rooms for the caller's groups, sends that echo back over the mock realtime bus
/// after `AppConfig.Chat.mockEchoDelay`, and, when asked (`-mock-chat-replies`), rooms of `mockLongRoomMessages`
/// rows and a fixture member who answers after `mockAutoReplyDelay`.
final class MockChatRepository: ChatRepository {
    private var rooms: [String: [ChatMessage]] = [:]
    private var replyIndex = 0
    private var sequence = 0
    private let groups: MockGroupRepository
    private let transport: MockRealtimeTransport
    private let identity: any IdentityProvider
    private let logger: any Logging
    /// Whether a fixture member answers every send (`-mock-chat-replies`).
    let autoReplies: Bool
    private let now: () -> Date
    private let sleep: Sleep

    init(groups: MockGroupRepository,
         transport: MockRealtimeTransport,
         identity: any IdentityProvider,
         logger: any Logging,
         autoReplies: Bool = false,
         now: @escaping () -> Date = { .now },
         sleep: @escaping Sleep = systemSleep) {
        self.groups = groups
        self.transport = transport
        self.identity = identity
        self.logger = logger
        self.autoReplies = autoReplies
        self.now = now
        self.sleep = sleep
    }

    func newest(groupID: String) async throws -> MessagePage {
        let (group, messages) = try await room(groupID)
        let size = AppConfig.Chat.historyPageSize
        return MessagePage(items: Array(messages.suffix(size)), hasMore: messages.count > size, channelEpoch: group.channelEpoch)
    }

    func older(groupID: String, before messageID: String) async throws -> MessagePage {
        let (group, messages) = try await room(groupID)
        let earlier = messages.filter { $0.id < messageID }
        let size = AppConfig.Chat.historyPageSize
        return MessagePage(items: Array(earlier.suffix(size)), hasMore: earlier.count > size, channelEpoch: group.channelEpoch)
    }

    func newer(groupID: String, after messageID: String) async throws -> MessagePage {
        let (group, messages) = try await room(groupID)
        let later = messages.filter { $0.id > messageID }
        let size = AppConfig.Chat.catchUpPageSize
        return MessagePage(items: Array(later.prefix(size)), hasMore: later.count > size, channelEpoch: group.channelEpoch)
    }

    /// Like the backend: the same client id from the same sender answers the stored message. A text starting with
    /// `AppConfig.Chat.mockFailingPrefix` is never stored and fails like a lost connection.
    func send(groupID: String, _ draft: MessageDraft) async throws -> SentMessage {
        let (group, messages) = try await room(groupID)
        guard !draft.trimmedText.hasPrefix(AppConfig.Chat.mockFailingPrefix) else { throw AppError.network }
        let callerID = identity.currentUserID ?? ""
        if let stored = messages.first(where: { $0.clientMessageId == draft.clientMessageID }) {
            guard stored.senderUserId == callerID else { throw AppError.messageSendFailed }
            logger.debug(.chat, "Mock send replayed for message \(stored.id)")
            return SentMessage(message: stored, channelEpoch: group.channelEpoch)
        }
        let message = ChatMessage(id: nextID(),
                                  groupId: groupID,
                                  senderUserId: callerID,
                                  senderName: AppBranding.Groups.Create.mockOwnerName,
                                  text: draft.trimmedText,
                                  clientMessageId: draft.clientMessageID,
                                  sentAt: now())
        rooms[groupID, default: []].append(message)
        publish(.message(message), to: group, after: AppConfig.Chat.mockEchoDelay)
        if autoReplies { scheduleReply(in: group) }
        return SentMessage(message: message, channelEpoch: group.channelEpoch)
    }

    func delete(groupID: String, messageID: String) async throws -> ChatMessage {
        let (group, messages) = try await room(groupID)
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { throw AppError.messageNotFound }
        let message = messages[index]
        guard message.isSent(by: identity.currentUserID) || group.role?.isAdmin == true else { throw AppError.insufficientRole }
        if message.isDeleted { return message }
        let deleted = message.markingDeleted()
        rooms[groupID]?[index] = deleted
        publish(.messageDeleted(groupID: groupID, id: messageID), to: group, after: AppConfig.Chat.mockEchoDelay)
        return deleted
    }

    /// The marker lives on the group mock's membership, so Mine reflects it on the next load.
    func markRead(groupID: String, messageID: String) async throws -> ReadMarker {
        let (group, _) = try await room(groupID)
        let marker = try groups.markRead(id: groupID, messageID: messageID)
        return ReadMarker(lastReadMessageId: marker, channelEpoch: group.channelEpoch)
    }

    /// The group as the caller may see it, and its rows, built on first access for the caller of that moment. Under
    /// `autoReplies` (the demo flag) rooms are deep enough to page.
    private func room(_ groupID: String) async throws -> (SportGroup, [ChatMessage]) {
        let group = try await groups.group(id: groupID)
        guard group.isMember else { throw AppError.notAMember }
        if rooms[groupID] == nil {
            rooms[groupID] = MockChatFixtures.messages(groupID: groupID,
                                                       callerID: identity.currentUserID ?? "",
                                                       callerName: AppBranding.Groups.Create.mockOwnerName,
                                                       now: now(),
                                                       count: autoReplies ? AppConfig.Chat.mockLongRoomMessages : nil)
        }
        return (group, rooms[groupID] ?? [])
    }

    /// Sorts after every fixture id and after every earlier send.
    private func nextID() -> String {
        sequence += 1
        return MockChatFixtures.messageID(groupID: "send", index: Int(now().timeIntervalSince1970 * 1000) * 1000 + sequence)
    }

    private func scheduleReply(in group: SportGroup) {
        let reply = MockChatFixtures.replies[replyIndex % MockChatFixtures.replies.count]
        replyIndex += 1
        let sender = MockChatFixtures.senders[0]
        let delay = AppConfig.Chat.mockAutoReplyDelay
        Task { [weak self, sleep] in
            guard (try? await sleep(delay)) != nil, let self else { return }
            let message = ChatMessage(id: nextID(),
                                      groupId: group.id,
                                      senderUserId: MockGroupFixtures.memberID(for: sender),
                                      senderName: sender,
                                      text: reply,
                                      sentAt: now())
            rooms[group.id, default: []].append(message)
            publish(.message(message), to: group, after: .zero)
        }
    }

    /// What the backend would publish after the commit, to the room's current channel.
    private func publish(_ envelope: RealtimeEnvelope, to group: SportGroup, after delay: Duration) {
        Task { [weak self, sleep] in
            guard (try? await sleep(delay)) != nil, let self else { return }
            transport.post(envelope, to: .room(groupID: group.id, epoch: group.channelEpoch))
        }
    }
}
