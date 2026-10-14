import SwiftUI

/// Draws the items `MessageMenuItems` decided for a long press on a bubble: reply, copy the text, delete when the
/// caller may, and for another member's live message Report (the report sheet over the message) and Block (after a
/// confirmation), both handed up to the transcript, which presents them. The transcript attaches the menu only when the
/// items hold something to tap.
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
