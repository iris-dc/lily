import SwiftUI

/// What a long press on a bubble offers: copy the text, delete when the caller may. Report and Block are listed but
/// disabled until moderation ships, so the menu's shape is final.
struct MessageContextMenu: View {
    let message: ChatMessage
    let viewModel: ChatViewModel

    private typealias Copy = AppBranding.Chat

    var body: some View {
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
