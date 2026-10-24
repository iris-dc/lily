import SwiftUI

/// One row of the transcript: a day chip, a member's bubble, a system note or one of the caller's unsent messages. A row
/// that arrived (`arrivedAt`) takes its height from nothing (`RowReveal`), fades in and grows from its sender's corner,
/// drawn from a clock (`MessageArrivalCurve`) while the arrival lasts, so the unsent bubble turning into the stored
/// message mid-way cuts nothing short. The timeline and the reveal wrap every row, paused and at full height when
/// nothing arrives, because a row that changed its structure when its arrival ended would rebuild its bubble and reload
/// its pictures.
struct ChatRowView: View {
    let row: ChatRow
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    /// The message a tapped quote led to, while its wash shows.
    let highlightedMessageID: String?
    let onTapQuote: (ReplyQuote) -> Void
    let onTapAttachment: (AttachmentSelection) -> Void
    let onOpenFile: (URL) -> Void
    let onReport: (ReportTarget) -> Void
    let onBlock: (MessageRow) -> Void
    let onShowVoters: (ChatMessage) -> Void
    /// When the row arrived; `nil` for a row that was there already.
    let arrivedAt: Date?
    /// Flipped when the arrival is over, so body runs again and the timeline pauses.
    @State private var hasArrived = false

    private let curve = MessageArrivalCurve.standard

    var body: some View {
        TimelineView(.animation(paused: !isArriving)) { context in
            let frame = arrivedAt.map { curve.frame(elapsed: context.date.timeIntervalSince($0)) } ?? .resting
            RowReveal(fraction: frame.reveal) {
                content
                    .opacity(frame.opacity)
                    .scaleEffect(frame.scale, anchor: row.arrivalCorner)
            }
        }
        .task(id: arrivedAt) { await waitForTheArrival() }
    }

    private var isArriving: Bool {
        guard let arrivedAt, !hasArrived else { return false }
        return Date.now.timeIntervalSince(arrivedAt) < curve.settlingDuration
    }

    private func waitForTheArrival() async {
        guard let arrivedAt else { return }
        let remaining = curve.settlingDuration - Date.now.timeIntervalSince(arrivedAt)
        guard remaining > 0, (try? await Task.sleep(for: .seconds(remaining))) != nil else { return }
        hasArrived = true
    }

    @ViewBuilder private var content: some View {
        switch row {
        case .day(let day):
            DaySeparator(day: day, now: viewModel.now())
        case .message(let messageRow):
            messageBubble(for: messageRow)
        case .system(let message):
            // Every chat is on the Chats stack, which registers the game and the tournament destinations; a pin's note
            // leads to the pinned message, as a quote does.
            SystemMessageRow(message: message, viewModel: viewModel, onTap: pinnedMessageTap(for: message)) {
                $0.open(through: dependencies.navigation)
            }
        case .pending(let pending):
            PendingMessageBubble(message: pending, viewModel: viewModel, onTapQuote: onTapQuote)
        }
    }

    /// A pin's note leads to the pinned message, as a quote does; any other note keeps its own tap.
    private func pinnedMessageTap(for message: ChatMessage) -> (() -> Void)? {
        guard message.kind == .messagePinned, let quote = message.replyTo else { return nil }
        return { onTapQuote(quote) }
    }

    /// The bubble, with a context menu only when `MessageMenuItems` offers something: an empty menu would still open on
    /// a long press, and a tombstone offers nothing.
    @ViewBuilder private func messageBubble(for messageRow: MessageRow) -> some View {
        let message = messageRow.message
        let items = MessageMenuItems.items(for: message,
                                           isOwn: messageRow.isOwn,
                                           canReply: viewModel.canReply(to: message),
                                           canDelete: viewModel.canDelete(message),
                                           pinning: viewModel.pinning(of: message),
                                           canRetractVote: viewModel.canRetractVote(in: message))
        let bubble = MessageBubble(row: messageRow,
                                   profile: viewModel.profile(of: messageRow),
                                   loader: viewModel.attachmentLoader,
                                   isQuoteDeleted: message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                                   onTapQuote: onTapQuote,
                                   onTapAttachment: onTapAttachment,
                                   onOpenFile: onOpenFile,
                                   onVote: { optionIDs in Task { await viewModel.vote(in: message, for: optionIDs) } },
                                   onShowVoters: { onShowVoters(message) })
            .messageHighlight(highlightedMessageID == message.id)
        if items.hasEnabledItems {
            bubble.contextMenu {
                MessageContextMenu(items: items,
                                   row: messageRow,
                                   viewModel: viewModel,
                                   onReport: { onReport(viewModel.reportTarget(for: message)) },
                                   onBlock: { onBlock(messageRow) })
            }
        } else {
            bubble
        }
    }
}

private extension View {
    /// The accent wash on the message a quote led to; animated in and out.
    func messageHighlight(_ isOn: Bool) -> some View {
        background(Color.lilyAccent.opacity(isOn ? DesignTokens.Opacity.messageHighlight : 0),
                   in: .rect(cornerRadius: DesignTokens.Radius.md))
            .animation(.easeOut(duration: DesignTokens.Duration.normal), value: isOn)
    }
}
