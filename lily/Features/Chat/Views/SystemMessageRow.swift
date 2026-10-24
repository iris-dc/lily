import SwiftUI

/// A centred note about the group or the tournament: "Marta created Sunday 5-a-side", "The bracket is out",
/// "Marta 3–1 Noor", "Jonas pinned «Bring the balls»". Tapping it opens the game, or the tournament with the match
/// selected when the row names one; `onTap`, when given, is the tap instead (a pin's note leads to the message).
struct SystemMessageRow: View {
    let message: ChatMessage
    let viewModel: ChatViewModel
    var onTap: (() -> Void)?
    let onOpen: (SystemRowDestination) -> Void

    var body: some View {
        Button {
            if let onTap { return onTap() }
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
        if message.kind == .messagePinned { return DesignTokens.Symbols.pin }
        return message.kind.isTournamentNote ? DesignTokens.Symbols.tournament : DesignTokens.Symbols.game
    }
}
