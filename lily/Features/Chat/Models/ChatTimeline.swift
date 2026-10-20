import Foundation

/// Turns a room's messages into rows: blocked senders and rows of a kind this build does not know hidden, system
/// notes centred, day dividers between days, one sender's messages within `groupingWindow` drawn as a run, the
/// caller's unsent messages at the end, their first one continuing the caller's run. Pure, so the rules are tested
/// without a view.
nonisolated enum ChatTimeline {
    struct Input {
        var messages: [ChatMessage]
        var pending: [PendingMessage] = []
        var blockedUserIDs: Set<String> = []
        /// The roster, for live names.
        var members: [GroupMember] = []
        var currentUserID: String?
        var groupingWindow: TimeInterval = AppConfig.Chat.groupingWindow
        var calendar = Calendar.autoupdatingCurrent
    }

    static func rows(_ input: Input) -> [ChatRow] {
        let visible = input.messages.filter { isShown($0, input) }
        // A catch-up may hold the stored message before the send's answer confirms the bubble: one row, not two.
        let landed = Set(visible.compactMap(\.clientMessageId))
        let unsent = input.pending.filter { !landed.contains($0.clientMessageID) }
        let names = Dictionary(input.members.map { ($0.userId, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        var rows: [ChatRow] = []
        var previous: ChatMessage?
        for (index, message) in visible.enumerated() {
            if let previous, !input.calendar.isDate(previous.sentAt, inSameDayAs: message.sentAt) {
                rows.append(.day(input.calendar.startOfDay(for: message.sentAt)))
            } else if previous == nil {
                rows.append(.day(input.calendar.startOfDay(for: message.sentAt)))
            }
            if message.isSystem {
                rows.append(.system(message))
            } else {
                let next = visible.indices.contains(index + 1) ? visible[index + 1] : nil
                let runsOn = next.map { continuesRun(from: message, to: $0, input) }
                    ?? continuesRun(from: message, into: unsent.first, input)
                rows.append(.message(MessageRow(message: message,
                                                isOwn: message.isSent(by: input.currentUserID),
                                                senderName: names[message.senderUserId] ?? message.senderName,
                                                isFirstInRun: !continuesRun(from: previous, to: message, input),
                                                isLastInRun: !runsOn)))
            }
            previous = message
        }
        rows += unsent.map(ChatRow.pending)
        return rows
    }

    /// A blocked sender's rows are hidden, and so is a row of a kind this build does not know: nothing is better than
    /// a wrong line, and the day dividers and runs are judged over what is shown.
    private static func isShown(_ message: ChatMessage, _ input: Input) -> Bool {
        !input.blockedUserIDs.contains(message.senderUserId) && !message.kind.isUnknown
    }

    /// The caller's newest message runs on into their first unsent one as it will once that is stored, so the
    /// confirmation moves its time to the new bubble without changing any row's height; a failed one shows its hint
    /// instead of a time, so the message before it keeps its own.
    private static func continuesRun(from message: ChatMessage, into unsent: PendingMessage?, _ input: Input) -> Bool {
        guard let unsent, !unsent.hasFailed, !message.isSystem, message.isSent(by: input.currentUserID) else { return false }
        return unsent.sentAt.timeIntervalSince(message.sentAt) < input.groupingWindow
            && input.calendar.isDate(message.sentAt, inSameDayAs: unsent.sentAt)
    }

    /// Two consecutive text messages of one sender, close in time and on the same day, form one run.
    private static func continuesRun(from earlier: ChatMessage?, to later: ChatMessage?, _ input: Input) -> Bool {
        guard let earlier, let later, !earlier.isSystem, !later.isSystem else { return false }
        return earlier.senderUserId == later.senderUserId
            && later.sentAt.timeIntervalSince(earlier.sentAt) < input.groupingWindow
            && input.calendar.isDate(earlier.sentAt, inSameDayAs: later.sentAt)
    }
}
