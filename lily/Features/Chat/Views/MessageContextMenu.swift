import SwiftUI

/// The long-press menu of a bubble, drawing what `MessageMenuItems` decided: Reply, Copy, Pin or Unpin, Retract vote,
/// Delete, and for another member's live message Report and Block, which the transcript presents through `onReport` and
/// `onBlock`.
struct MessageContextMenu: View {
    let items: MessageMenuItems
    let row: MessageRow
    let viewModel: ChatViewModel
    let onReport: () -> Void
    let onBlock: () -> Void

    private typealias Copy = AppBranding.Chat

    private var message: ChatMessage { row.message }

    var body: some View {
        if items.offers(.reply) {
            Button(Copy.reply, systemImage: DesignTokens.Symbols.reply) { viewModel.startReply(to: row) }
        }
        if items.offers(.copy) {
            Button(Copy.copyMessage, systemImage: DesignTokens.Symbols.copy) { viewModel.copy(message) }
        }
        if items.offers(.pin) {
            Button(Copy.Pins.pin, systemImage: DesignTokens.Symbols.pin) { Task { await viewModel.pin(message) } }
                .accessibilityIdentifier(AccessibilityIdentifiers.messagePin)
        }
        if items.offers(.unpin) {
            Button(Copy.Pins.unpin, systemImage: DesignTokens.Symbols.unpin) { Task { await viewModel.unpin(message.id) } }
                .accessibilityIdentifier(AccessibilityIdentifiers.messageUnpin)
        }
        if items.offers(.retractVote) {
            Button(Copy.Polls.retractVote, systemImage: DesignTokens.Symbols.retractVote) {
                Task { await viewModel.retractVote(in: message) }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.messageRetractVote)
        }
        if items.offers(.delete) {
            Button(Copy.deleteMessage, systemImage: DesignTokens.Symbols.delete, role: .destructive) {
                Task { await viewModel.delete(message) }
            }
        }
        if items.offers(.report) {
            Button(AppBranding.Moderation.reportMessage, systemImage: DesignTokens.Symbols.report, action: onReport)
                .accessibilityIdentifier(AccessibilityIdentifiers.messageReport)
        }
        if items.offers(.block) {
            Button(AppBranding.Moderation.block, systemImage: DesignTokens.Symbols.block, role: .destructive, action: onBlock)
                .accessibilityIdentifier(AccessibilityIdentifiers.messageBlock)
        }
    }
}
