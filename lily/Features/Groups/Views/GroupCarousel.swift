import SwiftUI

/// The public groups above the Explore list, Meetup-style: a "Groups" heading with "See all", and two rows of tiles
/// that scroll together sideways. Nothing at all until Discover has answered with at least one group, so the list
/// above which it sits gains no gap meanwhile.
struct GroupCarousel: View {
    let viewModel: GroupListViewModel

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
                tiles
            }
        }
    }

    private var tiles: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.groups) { group in
                    NavigationLink(value: group) {
                        GroupTile(group: group, distance: viewModel.distanceText(for: group))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
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
