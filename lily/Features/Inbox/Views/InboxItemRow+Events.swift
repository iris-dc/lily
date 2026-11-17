import SwiftUI

/// Noor asks the caller into an event: the calendar mark, the sentence naming the event, its type and start
/// ("Tennis · Today, 6:30 PM · in 1 hour"), then Accept / Decline or the status; the tournament card's shape.
struct EventInviteCard: View {
    let item: InboxItem
    let invite: EventInvitePayload
    let viewModel: InboxViewModel

    var body: some View {
        InboxInviteCard(item: item,
                        viewModel: viewModel,
                        inviter: invite.inviterName,
                        target: invite.title,
                        status: invite.statusCaption(now: viewModel.now())) {
            AvatarCircle(systemImage: DesignTokens.Symbols.game,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .secondary)
        } details: {
            Label(invite.details(now: viewModel.now()), systemImage: invite.type.symbolName)
        }
    }
}
