import Foundation

/// Sending, retrying and deleting. A send shows its bubble at once and keeps its client id through every retry, so the
/// backend replays instead of duplicating; an answer that never came is settled by a catch-up before Retry is offered.
extension ChatViewModel {
    func send() async {
        guard canSend else { return }
        let draft = self.draft
        self.draft = MessageDraft()
        pending.append(PendingMessage(draft: draft, sentAt: now()))
        await perform(draft)
    }

    func retry(_ message: PendingMessage) async {
        guard !isCoolingDown, let index = pending.firstIndex(of: message) else { return }
        pending[index].state = .sending
        await perform(message.draft)
    }

    func discard(_ message: PendingMessage) {
        pending.removeAll { $0.id == message.id }
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

    private func perform(_ draft: MessageDraft) async {
        do {
            let sent = try await repository.send(groupID: group.id, draft)
            settle(draft.clientMessageID, with: sent.message)
            logger.info(.chat, "Message sent \(sent.message.id) in group \(group.id)")
            noteRead()
            await adoptEpoch(sent.channelEpoch)
        } catch {
            await handleSendFailure(error, clientMessageID: draft.clientMessageID)
        }
    }

    /// The stored message replaces the bubble; the live echo arriving first has already done so.
    private func settle(_ clientMessageID: String, with message: ChatMessage) {
        mutateRoom { $0.insert(message) }
        pending.removeAll { $0.clientMessageID == clientMessageID }
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
        if case .rateLimited(let retryAfter) = error as? AppError {
            cooldownUntil = now().addingTimeInterval(retryAfter ?? AppConfig.Chat.rateLimitCooldownFallback)
        }
        report(error, during: "Send")
    }

    /// The backend commits before it answers: after a lost answer the catch-up may already show the message.
    private func landed(_ clientMessageID: String) async -> Bool {
        logger.warning(.chat, "Send outcome unknown for \(clientMessageID) in group \(group.id); catching up")
        do {
            try await catchUp.catchUp(groupID: group.id)
        } catch {
            logger.warning(.chat, "Catch-up after an unknown send outcome failed in group \(group.id): \(error)")
        }
        guard room.contains(clientMessageID: clientMessageID) else { return false }
        pending.removeAll { $0.clientMessageID == clientMessageID }
        return true
    }

    private func markFailed(_ clientMessageID: String) {
        if let index = pending.firstIndex(where: { $0.clientMessageID == clientMessageID }) {
            pending[index].state = .failed
        }
    }
}
