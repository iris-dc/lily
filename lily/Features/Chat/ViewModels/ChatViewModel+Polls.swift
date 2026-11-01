import Foundation

/// Polls: sending one through the same pending bubble and retries as a message, voting and taking a vote back, and the
/// voters of a public poll. A vote shows at once and the answer replaces it. After a lost answer the poll is refreshed
/// (`LostAnswer`) and the refreshed poll stays on screen whatever it says; the poll as it was returns only when a refusal
/// came or the refresh failed.
extension ChatViewModel {
    var canCreatePolls: Bool {
        GroupAccess(group: group, userID: identity.currentUserID).canCreatePolls(in: group)
    }

    func sendPoll(_ poll: PollDraft) async {
        guard poll.isValid, canCreatePolls, !isCoolingDown, !isGone else { return }
        var draft = MessageDraft()
        draft.poll = poll
        pending.append(PendingMessage(draft: draft, sentAt: now()))
        await perform(draft)
    }

    /// The caller's choice in the poll of `message`; `[]` takes the vote back.
    func vote(in message: ChatMessage, for optionIDs: [String]) async {
        guard !message.isDeleted, !room.isDeleted(id: message.id),
              let before = currentPoll(of: message.id) ?? message.poll else { return }
        mutateRoom { $0.applyPoll(messageID: message.id, poll: before.voting(optionIDs)) }
        do {
            let result = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                         logger: logger,
                                                         category: .chat,
                                                         retrying: "Vote in group \(group.id)") {
                try await repository.vote(groupID: group.id, messageID: message.id, optionIDs: optionIDs)
            }
            mutateRoom { $0.applyPoll(messageID: result.messageId, poll: result.poll, revision: result.pollRevision) }
            logger.info(.chat, "Vote of \(optionIDs.count) options in poll \(message.id) in group \(group.id)")
        } catch {
            let settled = await voteReadBack(for: message.id).settle("Vote in poll \(message.id)", despite: error) { state in
                state.map { Set($0.poll.myVotes) == Set(optionIDs) }
            }
            switch settled {
            case .landed:
                return
            case .didNotLand:
                break
            case .unresolved:
                mutateRoom { $0.applyPoll(messageID: message.id, poll: before) }
            }
            report(error, during: "Voting")
        }
    }

    func retractVote(in message: ChatMessage) async {
        await vote(in: message, for: [])
    }

    func canRetractVote(in message: ChatMessage) -> Bool {
        !message.isDeleted && (currentPoll(of: message.id) ?? message.poll)?.hasVoted == true
    }

    /// Who picked what in a public poll; `nil` after a failure, which reached the popup.
    func voters(of message: ChatMessage) async -> PollVoters? {
        do {
            return try await repository.voters(groupID: group.id, messageID: message.id)
        } catch {
            report(error, during: "Loading a poll's voters")
            return nil
        }
    }

    private func currentPoll(of messageID: String) -> Poll? {
        room.messages.first { $0.id == messageID }?.poll
    }

    /// The backend commits before it answers: after a lost answer the poll's state says whether the vote is in; a state
    /// the backend names replaces the one shown (other voters' counts stay), one it does not cannot tell.
    private func voteReadBack(for messageID: String) -> LostAnswer<PollState?> {
        LostAnswer(category: .chat,
                   logger: logger,
                   leavesOutcomeUnknown: { $0.leavesVoteOutcomeUnknown },
                   refetch: { [self] in
                       let states = try await repository.polls(groupID: group.id, messageIDs: [messageID])
                       return states.items.first { $0.messageId == messageID }
                   },
                   apply: { [self] state in
                       if let state { mutateRoom { $0.applyPoll(messageID: messageID, poll: state.poll) } }
                   })
    }
}
