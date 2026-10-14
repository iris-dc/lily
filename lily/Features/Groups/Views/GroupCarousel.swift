import SwiftUI

/// The public groups above the Explore list: a "Groups" heading with "See all" and two rows of tiles, through
/// `TileCarousel`, shown once Discover has answered with at least one group.
struct GroupCarousel: View {
    let viewModel: DiscoverGroupsViewModel

    var body: some View {
        TileCarousel(items: viewModel.groups,
                     title: AppBranding.Groups.title,
                     seeAll: DiscoverGroupsDestination(),
                     seeAllIdentifier: AccessibilityIdentifiers.groupsSeeAll,
                     identifier: AccessibilityIdentifiers.groupCarousel,
                     rows: DesignTokens.Layout.groupCarouselRows,
                     tileHeight: DesignTokens.Layout.groupTileHeight) { group, fillsWidth in
            GroupTileGrid.tile(for: group, distance: viewModel.distanceText(for: group), fillsWidth: fillsWidth)
        }
    }
}

/// Group tiles in a wrapping grid, for a regular width: the carousel's stand-in on Explore and the rows' on Home. Each
/// tile pushes the group on the stack it is in; every stack registers the group destinations.
struct GroupTileGrid: View {
    let groups: [SportGroup]
    let distance: (SportGroup) -> String?

    var body: some View {
        TileGrid(data: groups) { group in
            Self.tile(for: group, distance: distance(group), fillsWidth: true)
        }
    }

    static func tile(for group: SportGroup, distance: String?, fillsWidth: Bool) -> some View {
        TileLink(value: group, identifier: AccessibilityIdentifiers.groupRow(group.id)) {
            GroupTile(group: group, distance: distance, fillsWidth: fillsWidth)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let discover = dependencies.makeDiscoverGroupsViewModel()
    NavigationStack {
        ContentScreen {
            GroupCarousel(viewModel: discover)
        }
    }
    .task {
        await discover.loadUserLocation()
        await discover.loadIfStale()
    }
}
