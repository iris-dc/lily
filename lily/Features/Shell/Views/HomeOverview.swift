import SwiftUI

/// The signed-in Home content: a "Your groups" section of rows and a "Your games" section of cards, one scroll with
/// pull-to-refresh over both, and one state for the whole screen while nothing has loaded yet or nothing is there.
/// With groups switched off only the cards remain, without a heading of their own.
struct HomeOverview: View {
    let groups: MyGroupsStore
    let events: EventListViewModel
    let tournaments: TournamentListViewModel
    let dependencies: AppDependencies
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias Copy = AppBranding.Home

    private var showsGroups: Bool { AppConfig.FeatureFlags.groups }

    /// A list behind a flag that is off is left out, so the screen never waits for it.
    private var state: HomeOverviewState {
        .resolve(events: HomeListSnapshot(isEmpty: events.visibleEvents.isEmpty,
                                          hasAnswered: events.hasLoaded || events.loadFailed,
                                          loadFailed: events.loadFailed),
                 groups: showsGroups ? HomeListSnapshot(isEmpty: groups.communities.isEmpty,
                                                        hasAnswered: groups.hasLoaded || groups.loadFailed,
                                                        loadFailed: groups.loadFailed) : nil,
                 tournaments: AppConfig.FeatureFlags.tournaments
                     ? HomeListSnapshot(isEmpty: tournaments.visibleTournaments.isEmpty,
                                        hasAnswered: !tournaments.isInitialLoad,
                                        loadFailed: tournaments.loadFailed)
                     : nil)
    }

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .empty(let loadFailed):
            // Scrollable so the "pull to refresh" the failed state promises is possible from here.
            refreshableScroll { (loadFailed ? loadFailedState : emptyState).readableColumn().containerRelativeFrame(.vertical) }
        case .sections(let groupsState, let tournamentsState, let gamesState):
            refreshableScroll { sections(groups: groupsState, tournaments: tournamentsState, games: gamesState) }
        }
    }

    private func sections(groups: HomeSectionState?, tournaments: HomeSectionState?, games: HomeSectionState) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            if let groups {
                section(Copy.groupsSection) { groupsContent(groups) }
                if let tournaments {
                    section(AppBranding.Tournaments.mineSection) { tournamentsContent(tournaments) }
                }
                section(Copy.gamesSection) { gamesContent(games) }
            } else {
                gamesContent(games)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    /// A row (a tile in the regular-width grid) opens the group's detail, the place to manage a membership; its chat
    /// lives on the Chats tab.
    @ViewBuilder private func groupsContent(_ state: HomeSectionState) -> some View {
        switch state {
        case .content where sizeClass == .regular:
            GroupTileGrid(groups: groups.communities, distance: groupDistance)
        case .content:
            GroupRowList(groups: groups.communities) { dependencies.navigation.open(group: $0) }
        case .loading:
            loading
        case .failed:
            note(Copy.groupsLoadFailed)
        case .empty:
            note(Copy.noGroups)
        }
    }

    /// The tiles take the position the games section loads (`HomeView.loadIfStale` asks for it); Mine holds none.
    private func groupDistance(_ group: SportGroup) -> String? {
        group.distance(from: events.userLocation)?.roadText()
    }

    /// A card opens the tournament's detail, where entries are made and the organiser runs it.
    @ViewBuilder private func tournamentsContent(_ state: HomeSectionState) -> some View {
        if state == .failed {
            note(AppBranding.Tournaments.mineLoadFailed)
        } else {
            TournamentCardList(tournaments: tournaments.visibleTournaments, distance: tournaments.distanceText)
        }
    }

    @ViewBuilder private func gamesContent(_ state: HomeSectionState) -> some View {
        switch state {
        case .content:
            EventCardList(events: events.visibleEvents, distance: events.distanceText)
        case .loading:
            loading
        case .failed:
            note(Copy.gamesLoadFailed)
        case .empty:
            note(Copy.noGames)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionTitle(text: title)
            content()
        }
    }

    private var loading: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    private var emptyState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.home,
                       title: Copy.emptyTitle,
                       message: Copy.emptyMessage,
                       actionTitle: Copy.exploreAction) {
            dependencies.navigation.selectedTab = .explore
        }
    }

    private var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: Copy.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }

    /// Pull-to-refresh reloads both sections.
    private func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        ScrollView { content() }
            .refreshable {
                if showsGroups { await groups.reload() }
                if AppConfig.FeatureFlags.tournaments { await tournaments.load() }
                await events.load()
            }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            HomeOverview(groups: dependencies.myGroups,
                         events: dependencies.lists.homeEvents,
                         tournaments: dependencies.lists.homeTournaments,
                         dependencies: dependencies)
        }
    }
}
