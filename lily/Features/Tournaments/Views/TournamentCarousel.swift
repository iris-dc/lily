import SwiftUI

/// One tournament in the Explore carousel: the sport's glyph, the name and a one-line caption with the status and the
/// entries, on a fixed-size glass tile like a group's.
struct TournamentTile: View {
    let tournament: Tournament

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: "",
                         systemImage: tournament.type.symbolName,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(tournament.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(AppBranding.Groups.caption([tournament.entriesText, tournament.status.displayName]))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(width: DesignTokens.Layout.tournamentTileWidth, height: DesignTokens.Layout.tournamentTileHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.card))
        .contentShape(.rect)
    }
}

/// The public tournaments on Explore, under the groups carousel: a "Tournaments" heading with "See all" and one row of
/// tiles that scrolls sideways. Nothing at all until the list has answered with at least one tournament.
struct TournamentCarousel: View {
    let viewModel: TournamentListViewModel

    var body: some View {
        if !viewModel.visibleTournaments.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                SectionTitle(text: AppBranding.Tournaments.title) {
                    NavigationLink(value: DiscoverTournamentsDestination()) {
                        Text(AppBranding.Groups.seeAll)
                            .font(LilyTheme.Fonts.button)
                            .tappableLabel()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentsSeeAll)
                }
                tiles
            }
        }
    }

    private var tiles: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.visibleTournaments) { tournament in
                    NavigationLink(value: tournament.destination) {
                        TournamentTile(tournament: tournament)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentRow(tournament.id))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, DesignTokens.Layout.screenMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentCarousel)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let viewModel = dependencies.makeTournamentListViewModel(scope: .upcoming)
    NavigationStack {
        ContentScreen {
            TournamentCarousel(viewModel: viewModel)
        }
    }
    .task { await viewModel.loadIfStale() }
}
