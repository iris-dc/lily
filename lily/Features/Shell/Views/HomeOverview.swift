import SwiftUI

/// The signed-in Home content: a "Your groups" section of rows and a "Your games" section of cards, one scroll with
/// pull-to-refresh over both, and one state for the whole screen while nothing has loaded yet or nothing is there.
/// With groups switched off only the cards remain, without a heading of their own.
struct HomeOverview: View {
    let groups: GroupListViewModel
    let events: EventListViewModel
    let tournaments: TournamentListViewModel
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.Home

    private var showsGroups: Bool { AppConfig.FeatureFlags.groups }
    private var hasGroups: Bool { showsGroups && !groups.groups.isEmpty }
    private var hasGames: Bool { !events.visibleEvents.isEmpty }
    /// The section shows only while the caller organises or plays in something, or its load failed; most callers have none.
    private var showsTournaments: Bool {
        AppConfig.FeatureFlags.tournaments && (!tournaments.visibleTournaments.isEmpty || tournaments.loadFailed)
    }
    private var isEmpty: Bool { !hasGroups && !hasGames && !showsTournaments }
    private var isLoadingSomething: Bool { events.isInitialLoad || (showsGroups && groups.isInitialLoad) }
    private var loadFailed: Bool { events.loadFailed || (showsGroups && groups.loadFailed) }

    var body: some View {
        if isEmpty, isLoadingSomething {
            ProgressView()
        } else if isEmpty {
            // Scrollable so the "pull to refresh" the failed state promises is possible from here.
            refreshableScroll { (loadFailed ? loadFailedState : emptyState).containerRelativeFrame(.vertical) }
        } else {
            refreshableScroll { sections }
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            if showsGroups {
                section(Copy.groupsSection) { groupsContent }
                if showsTournaments {
                    section(AppBranding.Tournaments.mineSection) { tournamentsContent }
                }
                section(Copy.gamesSection) { gamesContent }
            } else {
                gamesContent
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    /// A row opens the group's detail, the place to manage a membership; its chat lives on the Chats tab.
    @ViewBuilder private var groupsContent: some View {
        if hasGroups {
            GroupRowList(groups: groups.groups) { dependencies.navigation.open(group: $0) }
        } else if groups.isInitialLoad {
            loading
        } else {
            note(groups.loadFailed ? Copy.groupsLoadFailed : Copy.noGroups)
        }
    }

    /// A card opens the tournament's detail, where entries are made and the organiser runs it.
    @ViewBuilder private var tournamentsContent: some View {
        if tournaments.loadFailed, tournaments.visibleTournaments.isEmpty {
            note(AppBranding.Tournaments.mineLoadFailed)
        } else {
            TournamentCardList(tournaments: tournaments.visibleTournaments, distance: tournaments.distanceText)
        }
    }

    @ViewBuilder private var gamesContent: some View {
        if hasGames {
            EventCardList(events: events.visibleEvents, distance: events.distanceText)
        } else if events.isInitialLoad {
            loading
        } else {
            note(events.loadFailed ? Copy.gamesLoadFailed : Copy.noGames)
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
        RefreshableScroll(action: {
            if showsGroups { await groups.refresh() }
            if AppConfig.FeatureFlags.tournaments { await tournaments.load() }
            await events.load()
        }, content: content)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            HomeOverview(groups: dependencies.makeGroupListViewModel(scope: .mine),
                         events: dependencies.makeEventListViewModel(scope: .joined),
                         tournaments: dependencies.makeTournamentListViewModel(scope: .mine),
                         dependencies: dependencies)
        }
    }
}
