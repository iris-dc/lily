import SwiftUI

/// The Players (or Teams) segment of a tournament's detail: every entry in seed order, each person opening their
/// profile, "Join team" on a team with room while the caller may still enter, and "Remove entry" for the organiser.
struct TournamentEntriesSegment: View {
    let viewModel: TournamentDetailViewModel
    let detail: TournamentDetail
    let onRemove: (TournamentEntry) -> Void

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if detail.registeredEntries.isEmpty {
                Text(Copy.noEntries)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(detail.registeredEntries.sorted { $0.seed < $1.seed }) { entry in
                EntryRow(entry: entry, viewModel: viewModel, teamSize: detail.tournament.teamSize)
                    .contextMenu {
                        if viewModel.canRemoveEntries {
                            Button(Copy.removeEntry, systemImage: DesignTokens.Symbols.delete, role: .destructive) {
                                onRemove(entry)
                            }
                        }
                    }
            }
        }
    }
}

/// One entry: a person's row for an individual tournament; for a team, its name with the seed and "N of M players",
/// the members as person rows under it, and "Join team" while the caller may still enter it.
struct EntryRow: View {
    let entry: TournamentEntry
    let viewModel: TournamentDetailViewModel
    let teamSize: Int

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        if teamSize > 1 {
            team
        } else if let player = entry.members.first {
            PersonRow(userID: player.userId,
                      displayName: player.displayName,
                      isSelf: viewModel.isSelf(player.userId),
                      identifier: AccessibilityIdentifiers.entryRow(entry.id)) {
                seedChip
            }
        }
    }

    private var team: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(entry.name).font(.body.weight(.semibold))
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    seedChip
                }
                Text(Copy.players(entry.memberCount, of: teamSize))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                ForEach(entry.members, id: \.userId) { member in
                    PersonRow(userID: member.userId,
                              displayName: member.displayName,
                              isSelf: viewModel.isSelf(member.userId),
                              identifier: AccessibilityIdentifiers.participantRow(member.userId)) {
                        if entry.isCaptain(member.userId) {
                            Label(Copy.captain, systemImage: DesignTokens.Symbols.captain).lilyChip(.regular)
                        }
                    }
                }
                if viewModel.canJoin(entry) {
                    joinButton
                }
            }
        }
        // A container's identifier would otherwise stamp every row; the rows keep theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.entryRow(entry.id))
    }

    private var seedChip: some View {
        Text(Copy.seed(entry.seed))
            .lilyChip(.regular)
            .fixedSize()
    }

    private var joinButton: some View {
        Button {
            Task { await viewModel.joinTeam(entry) }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(Copy.joinTeam)
                if viewModel.isBusy {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
        .disabled(viewModel.isBusy)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoinTeam(entry.id))
    }
}
