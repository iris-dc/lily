import Foundation

/// Polls and pins as the backend rules them: a vote replaces the caller's choice and moves the room's poll revision, an
/// anonymous poll keeps its voters, a pin needs an admin outside a conversation, refuses a system row or a deleted
/// message and posts the note Laurel posts, an unpin posts nothing.
extension MockChatRepository {
    func vote(groupID: String, messageID: String, optionIDs: [String]) async throws -> VoteResult {
        let (_, messages) = try await visibleRoom(groupID)
        guard let message = messages.first(where: { $0.id == messageID }), !message.isDeleted else {
            throw AppError.messageNotFound
        }
        guard let poll = message.poll else { throw AppError.notAPoll }
        let known = Set(poll.options.map(\.id))
        guard Set(optionIDs).count == optionIDs.count, optionIDs.allSatisfy(known.contains),
              poll.allowsMultipleAnswers || optionIDs.count <= 1 else { throw AppError.voteFailed }
        let voted = poll.voting(optionIDs)
        // The same choice again changes nothing and answers the current state, as the backend does.
        if voted != poll {
            replace(messageID, in: groupID) { $0.replacingPoll(voted) }
            pollRevisions[groupID] = (pollRevisions[groupID] ?? 0) + 1
        }
        return VoteResult(messageId: messageID, poll: voted, pollRevision: pollRevisions[groupID] ?? 0)
    }

    func polls(groupID: String, messageIDs: [String]) async throws -> PollStates {
        let (_, messages) = try await visibleRoom(groupID)
        let wanted = Set(messageIDs)
        let states = messages.filter { wanted.contains($0.id) && !$0.isDeleted }.compactMap { message in
            message.poll.map { PollState(messageId: message.id, poll: $0) }
        }
        return PollStates(items: states, pollRevision: pollRevisions[groupID] ?? 0)
    }

    /// The fixture voters, and the caller under the options they picked.
    func voters(groupID: String, messageID: String) async throws -> PollVoters {
        let (_, messages) = try await visibleRoom(groupID)
        guard let message = messages.first(where: { $0.id == messageID }), !message.isDeleted else {
            throw AppError.messageNotFound
        }
        guard let poll = message.poll else { throw AppError.notAPoll }
        guard !poll.isAnonymous else { throw AppError.pollAnonymous }
        let caller = PollVoters.Voter(userId: identity.currentUserID ?? "", name: AppBranding.Groups.Create.mockOwnerName)
        let fixture = pollVoters[messageID] ?? [:]
        return PollVoters(options: poll.options.map { option in
            let voters = (fixture[option.id] ?? []) + (poll.myVotes.contains(option.id) ? [caller] : [])
            return PollVoters.Option(id: option.id, voters: voters)
        })
    }

    func pin(groupID: String, messageID: String) async throws -> PinList {
        let (group, message) = try await pinTarget(groupID: groupID, messageID: messageID)
        let current = pins[groupID] ?? []
        guard !current.contains(where: { $0.messageId == messageID }) else {
            return PinList(pins: current, channelEpoch: group.channelEpoch)
        }
        guard current.count < AppConfig.Chat.Pins.maxPins else { throw AppError.tooManyPins }
        let quote = ReplyQuote(quoting: message, senderName: message.senderName)
        pins[groupID] = current + [PinnedMessage(quote: quote, pinnedAt: now())]
        post(ChatMessage(id: nextID(in: groupID),
                         groupId: groupID,
                         senderUserId: identity.currentUserID ?? "",
                         senderName: AppBranding.Groups.Create.mockOwnerName,
                         kind: .messagePinned,
                         sentAt: now(),
                         replyTo: quote),
             in: group,
             echoAfter: AppConfig.Chat.mockEchoDelay)
        return PinList(pins: pins[groupID] ?? [], channelEpoch: group.channelEpoch)
    }

    func unpin(groupID: String, messageID: String) async throws -> PinList {
        let (group, _) = try await room(groupID)
        try requirePinRights(in: group)
        pins[groupID]?.removeAll { $0.messageId == messageID }
        return PinList(pins: pins[groupID] ?? [], channelEpoch: group.channelEpoch)
    }

    private func pinTarget(groupID: String, messageID: String) async throws -> (SportGroup, ChatMessage) {
        let (group, messages) = try await visibleRoom(groupID)
        try requirePinRights(in: group)
        guard let message = messages.first(where: { $0.id == messageID }), !message.isDeleted else {
            throw AppError.messageNotFound
        }
        guard !message.isSystem else { throw AppError.notPinnable }
        return (group, message)
    }

    private func requirePinRights(in group: SportGroup) throws {
        guard group.isDirect || group.role?.isAdmin == true else { throw AppError.insufficientRole }
    }

    private func replace(_ messageID: String, in groupID: String, _ change: (ChatMessage) -> ChatMessage) {
        guard let index = rooms[groupID]?.firstIndex(where: { $0.id == messageID }), let message = rooms[groupID]?[index] else {
            return
        }
        rooms[groupID]?[index] = change(message)
    }
}
