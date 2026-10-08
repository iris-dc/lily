import SwiftUI

/// The public groups above the Explore list, Meetup-style: a "Groups" heading with "See all", and two rows of tiles
/// that scroll together sideways; on a regular width a wrapping grid of the first few instead (`TileGrid`), since a
/// sideways scroll on a screen that wide would leave most of it empty. Nothing at all until Discover has answered with
/// at least one group, so the list above which it sits gains no gap meanwhile.
struct GroupCarousel: View {
    let viewModel: GroupListViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(DesignTokens.Layout.groupTileHeight), spacing: DesignTokens.Spacing.md),
              count: DesignTokens.Layout.groupCarouselRows)
    }

    var body: some View {
        if !viewModel.groups.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                SectionTitle(text: AppBranding.Groups.title) {
                    NavigationLink(value: DiscoverGroupsDestination()) {
                        Text(AppBranding.Groups.seeAll)
                            .font(LilyTheme.Fonts.button)
                            .tappableLabel()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityIdentifiers.groupsSeeAll)
                }
                if sizeClass == .regular {
                    grid
                } else {
                    tiles
                }
            }
        }
    }

    private var grid: some View {
        GroupTileGrid(groups: viewModel.groups, distance: viewModel.distanceText)
            // A container's identifier would otherwise be stamped on every tile and hide theirs.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.groupCarousel)
    }

    private var tiles: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.groups) { group in
                    GroupTileGrid.tile(for: group, distance: viewModel.distanceText(for: group), fillsWidth: false)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, DesignTokens.Layout.screenMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(AccessibilityIdentifiers.groupCarousel)
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
        NavigationLink(value: group) {
            GroupTile(group: group, distance: distance, fillsWidth: fillsWidth)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let discover = dependencies.makeGroupListViewModel(scope: .discover)
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
