import SwiftUI

/// One item of the inbox as a system card on the surface colour (a plain fill, never glass: the list draws many at
/// once): an invite into a group or a tournament with Accept / Decline while it is open and its status once it is not,
/// or a reminder that opens its game or its match's tournament. The parts are `InboxCardParts.swift`, the tournament
/// cards `InboxItemRow+Tournaments.swift`. A kind this build cannot draw renders nothing.
struct InboxItemRow: View {
    let item: InboxItem
    let viewModel: InboxViewModel

    var body: some View {
        if let invite = item.invite {
            InviteCard(item: item, invite: invite, viewModel: viewModel)
        } else if let reminder = item.reminder {
            ReminderCard(item: item, reminder: reminder, viewModel: viewModel)
        } else if let invite = item.tournamentInvite {
            TournamentInviteCard(item: item, invite: invite, viewModel: viewModel)
        } else if let reminder = item.matchReminder {
            MatchReminderCard(item: item, reminder: reminder, viewModel: viewModel)
        }
    }
}

private struct InviteCard: View {
    let item: InboxItem
    let invite: InvitePayload
    let viewModel: InboxViewModel

    var body: some View {
        InboxInviteCard(item: item,
                        viewModel: viewModel,
                        inviter: invite.inviterName,
                        target: invite.groupName,
                        status: invite.statusCaption(now: viewModel.now())) {
            AvatarCircle(initials: invite.groupName.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
        } details: {
            Label(invite.groupVisibility.displayName, systemImage: invite.groupVisibility.symbolName)
        }
    }
}

private struct ReminderCard: View {
    let item: InboxItem
    let reminder: ReminderPayload
    let viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox

    var body: some View {
        InboxOpenCard(item: item, isBusy: viewModel.isBusy(item), symbol: DesignTokens.Symbols.game, openLabel: Copy.openGame) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(Copy.reminderTitle)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: reminder.title)
                    .font(.body.weight(.semibold))
                Label(reminder.locationName, systemImage: DesignTokens.Symbols.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(reminder.startsAtCaption(now: viewModel.now()), systemImage: DesignTokens.Symbols.time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let groupName = reminder.groupName {
                    Text(AppBranding.Groups.hostedIn(groupName: groupName))
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } action: {
            Task { await viewModel.openEvent(for: item) }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let viewModel = dependencies.makeInboxViewModel()
    ContentScreen {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(MockInboxFixtures.make(now: .now)) { InboxItemRow(item: $0, viewModel: viewModel) }
            }
            .padding()
        }
    }
}
