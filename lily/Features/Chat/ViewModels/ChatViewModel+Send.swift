import Foundation

/// Sending, retrying and deleting. A send shows its bubble at once and keeps its client id through every retry, so the
/// backend replays instead of duplicating; a `TRY_AGAIN` (the sender's own overlapping writes racing on the backend)
/// is repeated once by itself, and an answer that never came is settled by a catch-up before Retry is offered.
extension ChatViewModel {
    func send() async {
        guard canSend else { return }
        let draft = outgoingDraft
        self.draft = MessageDraft()
        attachments.reset()
        pending.append(PendingMessage(draft: draft, sentAt: now()))
        await perform(draft)
    }

    /// Sends the bubble's draft again under the same client id. The bubble is looked up by that id rather than trusting
    /// the copy the tap carries, which may be stale: a quote dropped meanwhile must go out dropped, and a second tap
    /// landing before the first re-rendered finds the bubble `.sending` and sends nothing more.
    func retry(_ message: PendingMessage) async {
        guard !isCoolingDown,
              let current = pending.first(where: { $0.clientMessageID == message.clientMessageID }),
              current.hasFailed else { return }
        updatePending(current.clientMessageID) { $0.state = .sending }
        await perform(current.draft)
    }

    /// Drops the bubble for good: its files leave the device with it (a failed bubble keeps them for Retry until then).
    func discard(_ message: PendingMessage) {
        pending.removeAll { $0.id == message.id }
        message.deleteLocalFiles()
    }

    func delete(_ message: ChatMessage) async {
        do {
            _ = try await repository.delete(groupID: group.id, messageID: message.id)
            mutateRoom { $0.markDeleted(id: message.id) }
            logger.info(.chat, "Message \(message.id) deleted in group \(group.id)")
        } catch {
            report(error, during: "Deleting a message")
        }
    }

    /// Changes the bubble of `clientMessageID` in place; a bubble already replaced or discarded is left alone.
    func updatePending(_ clientMessageID: String, _ change: (inout PendingMessage) -> Void) {
        guard let index = pending.firstIndex(where: { $0.clientMessageID == clientMessageID }) else { return }
        change(&pending[index])
    }

    private func perform(_ draft: MessageDraft) async {
        do {
            let sent = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                       logger: logger,
                                                       category: .chat,
                                                       retrying: "Send in group \(group.id)") {
                try await repository.send(groupID: group.id, draft)
            }
            await settle(draft.clientMessageID, with: sent.message)
            logger.info(.chat, "Message sent \(sent.message.id) in group \(group.id)")
            noteRead()
            await adoptEpoch(sent.channelEpoch)
        } catch {
            await handleSendFailure(error, clientMessageID: draft.clientMessageID)
        }
    }

    /// The stored message replaces the bubble (the live echo arriving first has already done so). The bubble's files are
    /// seeded before the message goes in, or its thumbnail request would download what was just sent; `mutateRoom`
    /// re-reads the room after the await, so a room dropped meanwhile is not re-created.
    private func settle(_ clientMessageID: String, with message: ChatMessage) async {
        await confirmPending(clientMessageID: clientMessageID, with: message)
        mutateRoom { $0.insert(message) }
    }

    private func handleSendFailure(_ error: any Error, clientMessageID: String) async {
        guard !AppError.isCancellation(error) else {
            markFailed(clientMessageID)
            return
        }
        if let appError = error as? AppError, appError.leavesSendOutcomeUnknown, await landed(clientMessageID) {
            logger.info(.chat, "Send landed for \(clientMessageID) in group \(group.id) despite \(appError)")
            return
        }
        markFailed(clientMessageID)
        switch error as? AppError {
        case .rateLimited(let retryAfter):
            cooldownUntil = now().addingTimeInterval(retryAfter ?? AppConfig.Chat.rateLimitCooldownFallback)
        case .replyTargetNotFound:
            dropReply(from: clientMessageID)
        default:
            break
        }
        report(error, during: "Send")
    }

    /// The backend commits before it answers: after a lost answer the catch-up may already show the message, which
    /// then replaces the bubble like an answer would.
    private func landed(_ clientMessageID: String) async -> Bool {
        logger.warning(.chat, "Send outcome unknown for \(clientMessageID) in group \(group.id); catching up")
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            logger.warning(.chat, "Catch-up after an unknown send outcome failed in group \(group.id): \(error)")
        }
        guard let message = room.message(clientMessageID: clientMessageID) else { return false }
        await confirmPending(clientMessageID: clientMessageID, with: message)
        return true
    }

    private func markFailed(_ clientMessageID: String) {
        updatePending(clientMessageID) { $0.state = .failed }
    }
}
