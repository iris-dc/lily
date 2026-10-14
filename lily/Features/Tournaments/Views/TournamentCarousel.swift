import SwiftUI

/// One tournament in the Explore carousel: the sport's glyph, the name and a one-line caption with the status and the
/// entries, on a fixed-size glass tile like a group's.
struct TournamentTile: View {
    let tournament: Tournament
    /// In a wrapping grid the tile takes its cell's width; in the carousel it keeps the fixed one.
    var fillsWidth = false

    var body: some View {
        TileContent(avatar: AvatarCircle(systemImage: tournament.type.symbolName,
                                         size: DesignTokens.Layout.avatarMedium,
                                         tint: .secondary),
                    title: tournament.name,
                    lines: [AppBranding.Groups.caption([tournament.entriesText, tournament.status.displayName])])
            .glassTile(fixedWidth: DesignTokens.Layout.tournamentTileWidth,
                       height: DesignTokens.Layout.tournamentTileHeight,
                       fillsWidth: fillsWidth)
    }
}

/// The public tournaments on Explore, under the groups carousel: a "Tournaments" heading with "See all" and one row of
/// tiles, through `TileCarousel`, shown once the list has answered with at least one tournament.
struct TournamentCarousel: View {
    let viewModel: TournamentListViewModel

    var body: some View {
        TileCarousel(items: viewModel.visibleTournaments,
                     title: AppBranding.Tournaments.title,
                     seeAll: DiscoverTournamentsDestination(),
                     seeAllIdentifier: AccessibilityIdentifiers.tournamentsSeeAll,
                     identifier: AccessibilityIdentifiers.tournamentCarousel,
                     tileHeight: DesignTokens.Layout.tournamentTileHeight) { tournament, fillsWidth in
            TileLink(value: tournament.destination, identifier: AccessibilityIdentifiers.tournamentRow(tournament.id)) {
                TournamentTile(tournament: tournament, fillsWidth: fillsWidth)
            }
        }
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
