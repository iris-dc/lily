import SwiftUI

/// The signed-in Home content: a "Your groups" section of rows and a "Your games" section of cards, one scroll with
/// pull-to-refresh over both, and one state for the whole screen while nothing has loaded yet or nothing is there.
/// With groups switched off only the cards remain, without a heading of their own.
struct HomeOverview: View {
    let groups: GroupListViewModel
    let events: EventListViewModel
    let dependencies: AppDependencies

    private typealias Copy = AppBranding.Home

    private var showsGroups: Bool { AppConfig.FeatureFlags.groups }
    private var hasGroups: Bool { showsGroups && !groups.groups.isEmpty }
    private var hasGames: Bool { !events.visibleEvents.isEmpty }
    private var isEmpty: Bool { !hasGroups && !hasGames }
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
                section(Copy.gamesSection) { gamesContent }
            } else {
                gamesContent
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    @ViewBuilder private var groupsContent: some View {
        if hasGroups {
            GroupRowList(groups: groups.groups, unread: dependencies.unreadCenter) {
                dependencies.navigation.open(chat: $0)
            }
        } else if groups.isInitialLoad {
            loading
        } else {
            note(groups.loadFailed ? Copy.groupsLoadFailed : Copy.noGroups)
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
                         dependencies: dependencies)
        }
    }
}
