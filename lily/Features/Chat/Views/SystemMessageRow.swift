import SwiftUI

/// A centred note about the group: "Marta created Sunday 5-a-side". Tapping it opens the game.
struct SystemMessageRow: View {
    let message: ChatMessage
    let viewModel: ChatViewModel
    let onOpen: (SportEvent) -> Void

    var body: some View {
        Button {
            Task {
                if let event = await viewModel.eventToOpen(for: message) { onOpen(event) }
            }
        } label: {
            Label(viewModel.systemText(for: message), systemImage: DesignTokens.Symbols.myEvents)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .tappableLabel()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.message(id: message.id))
        .task { await viewModel.loadEvent(for: message) }
    }
}
