import SwiftUI

/// What a long press on a bubble offers: reply to it (any member's message that is not deleted), copy the text, delete
/// when the caller may. Report and Block are listed but disabled until moderation ships, so the menu's shape is final.
struct MessageContextMenu: View {
    let row: MessageRow
    let viewModel: ChatViewModel

    private typealias Copy = AppBranding.Chat

    private var message: ChatMessage { row.message }

    var body: some View {
        if viewModel.canReply(to: message) {
            Button(Copy.reply, systemImage: DesignTokens.Symbols.reply) { viewModel.startReply(to: row) }
        }
        if message.text != nil {
            Button(Copy.copyMessage, systemImage: DesignTokens.Symbols.copy) { viewModel.copy(message) }
        }
        if viewModel.canDelete(message) {
            Button(Copy.deleteMessage, systemImage: DesignTokens.Symbols.delete, role: .destructive) {
                Task { await viewModel.delete(message) }
            }
        }
        if !message.isSent(by: viewModel.identity.currentUserID) {
            Button(AppBranding.Moderation.reportMessage, systemImage: DesignTokens.Symbols.report) {}
                .disabled(true)
            Button(AppBranding.Moderation.block, systemImage: DesignTokens.Symbols.block) {}
                .disabled(true)
        }
    }
}
