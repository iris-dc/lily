import SwiftUI

/// A joined upcoming game was cancelled by its host's account deletion: the warning mark, the sentence with the
/// title in bold, and when it would have started. A plain card — the event is gone, so there is nothing to open.
struct EventCancelledCard: View {
    let item: InboxItem
    let payload: EventCancelledPayload
    let viewModel: InboxViewModel

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            AvatarCircle(systemImage: DesignTokens.Symbols.eventCancelled,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .secondary)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                NoticeSentence(name: payload.title, copy: AppBranding.Inbox.wasCancelled)
                    .font(.body)
                Label(payload.startsAtCaption(now: viewModel.now()), systemImage: DesignTokens.Symbols.time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .inboxCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxItem(item.id))
    }
}

/// A group whose owner deleted their account is the caller's now: the owner's mark, the sentence with the name in
/// bold, and a tap that opens the group on Home.
struct GroupOwnershipCard: View {
    let item: InboxItem
    let payload: GroupOwnershipTransferredPayload
    let viewModel: InboxViewModel

    var body: some View {
        InboxOpenCard(item: item,
                      isBusy: viewModel.isBusy(item),
                      symbol: DesignTokens.Symbols.owner,
                      openLabel: AppBranding.Inbox.openGroup) {
            NoticeSentence(name: payload.groupName, copy: AppBranding.Inbox.isNowYours)
                .font(.body)
        } action: {
            Task { await viewModel.openGroup(for: item) }
        }
    }
}
