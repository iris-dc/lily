import SwiftUI

/// Noor asks the caller into a tournament: the trophy for the mark, the sentence, what kind of tournament it is
/// ("Football · Single elimination · Teams of 5"), then Accept / Decline or the status.
struct TournamentInviteCard: View {
    let item: InboxItem
    let invite: TournamentInvitePayload
    let viewModel: InboxViewModel

    var body: some View {
        InboxInviteCard(item: item,
                        viewModel: viewModel,
                        inviter: invite.inviterName,
                        target: invite.tournamentName,
                        status: invite.statusCaption(now: viewModel.now())) {
            AvatarCircle(initials: "",
                         systemImage: DesignTokens.Symbols.tournament,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
        } details: {
            Label(invite.details, systemImage: invite.type.symbolName)
        }
    }
}

/// The caller's match an hour ahead: the tournament, the opponent, the place when set and the time, opening the
/// tournament with that match's sheet up.
struct MatchReminderCard: View {
    let item: InboxItem
    let reminder: MatchReminderPayload
    let viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox

    var body: some View {
        InboxOpenCard(item: item,
                      isBusy: viewModel.isBusy(item),
                      symbol: DesignTokens.Symbols.tournament,
                      openLabel: Copy.openTournament) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(Copy.matchReminderTitle)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: reminder.tournamentName)
                    .font(.body.weight(.semibold))
                Text(Copy.versus(reminder.opponentName))
                    .font(.subheadline)
                if let place = reminder.locationName {
                    Label(place, systemImage: DesignTokens.Symbols.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(reminder.startsAtCaption(now: viewModel.now()), systemImage: DesignTokens.Symbols.time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } action: {
            viewModel.openTournament(for: item)
        }
    }
}
