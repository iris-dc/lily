import SwiftUI

/// A centred note about the group or the tournament: "Marta created Sunday 5-a-side", "The bracket is out",
/// "Marta 3–1 Noor". Tapping it opens the game, or the tournament with the match selected when the row names one.
struct SystemMessageRow: View {
    let message: ChatMessage
    let viewModel: ChatViewModel
    let onOpen: (SystemRowDestination) -> Void

    var body: some View {
        Button {
            Task {
                if let destination = await viewModel.destination(for: message) { onOpen(destination) }
            }
        } label: {
            Label(viewModel.systemText(for: message), systemImage: symbolName)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .tappableLabel()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.message(id: message.id))
        .task { await viewModel.loadLinkedContent(for: message) }
    }

    private var symbolName: String {
        if message.kind == .matchDisputed { return DesignTokens.Symbols.disputed }
        return message.kind.isTournamentNote ? DesignTokens.Symbols.tournament : DesignTokens.Symbols.game
    }
}
