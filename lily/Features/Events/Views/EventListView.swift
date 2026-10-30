import SwiftUI

/// The Explore screen: the upcoming games as a list, switchable to a map, narrowed through the filter panel dropped
/// down from the toolbar, with the "+" menu floating over the content (a signed-in user gets the game, group or
/// tournament form, a guest the sign-in sheet) and a header (the carousels) above the list. On a wide window
/// (`LayoutMode.wide`) the map is not a mode but a pane: the content column on the left, the map always on the right,
/// and the picker gone (`EventListLayout`).
struct EventListView<Header: View>: View {
    /// Heading over the cards, for a screen whose header (the groups carousel) would otherwise make them read as its.
    let listTitle: String?
    /// The upcoming list, owned by `ShellLists` for the app's lifetime, so it holds content before this screen exists.
    let viewModel: EventListViewModel
    let dependencies: AppDependencies
    let header: () -> Header
    /// Pull-to-refresh reloads the header's content too (the carousel), before the events.
    let refreshHeader: () async -> Void
    @State var presentation: EventsPresentation = .list
    @State var presentedSheet: ExploreSheet?
    /// The header's measured height: a spinner or empty state is centred in what the screen leaves under it.
    @State var headerHeight: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutMode) private var layoutMode

    private var layout: EventListLayout { .resolve(mode: layoutMode) }
    /// Whether the map is the whole content right now: the switchable layout with the picker on "Map".
    var showsMapAlone: Bool { layout == .switchable && presentation == .map }

    init(listTitle: String?,
         viewModel: EventListViewModel,
         dependencies: AppDependencies,
         refreshHeader: @escaping () async -> Void,
         @ViewBuilder header: @escaping () -> Header) {
        self.listTitle = listTitle
        self.viewModel = viewModel
        self.dependencies = dependencies
        self.header = header
        self.refreshHeader = refreshHeader
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                screen
            }
            .navigationTitle(AppBranding.exploreTitle)
            .navigationBarTitleDisplayMode(showsMapAlone ? .inline : .large)
            .navigationDestination(for: SportEvent.self) { event in
                // A join or leave on the detail comes back through `replace`, so this list is right on return.
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: viewModel.replace),
                                dependencies: dependencies)
            }
            // An event's "Hosted in" link and the carousel push groups here, so every stack knows the group screens.
            .groupDestinations(dependencies: dependencies)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EventFilterButton(viewModel: viewModel) }
                if layout == .switchable {
                    // iOS 26 gives every toolbar item its own glass; the segmented picker already draws one.
                    ToolbarItem(placement: .topBarTrailing) { presentationPicker }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
        }
        // Re-runs when a game changes anywhere (a create from a group's detail pushed on this stack), so the list behind
        // the detail is right on return, not only on the next appearance.
        .task(id: dependencies.eventChanges.version) { await viewModel.loadIfStale() }
        .task { await viewModel.loadUserLocation() }
        .onChange(of: presentation) { viewModel.presentationChanged(to: presentation) }
        // Coming back to the foreground is the one moment location permission may have changed (Settings), and the
        // user may have moved meanwhile, so the position is asked for again; the cache answers within its TTL.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await viewModel.refreshUserLocation() } }
        }
        // A shortcut's create waits on the navigation until Explore is on screen; `initial` catches one that arrived
        // while another tab was showing.
        .onChange(of: dependencies.navigation.pendingCreate, initial: true) { consumePendingCreate() }
        .sheet(item: $presentedSheet) { sheet in sheetContent(for: sheet) }
    }

    /// One column with the list or the map, or, side by side, the content column (with the "+" over its corner) and
    /// the map pane taking the rest of the width.
    @ViewBuilder
    private var screen: some View {
        switch layout {
        case .switchable:
            withCreateButton(content)
        case .sideBySide:
            HStack(spacing: 0) {
                withCreateButton(listContent)
                    .containerRelativeFrame(.horizontal) { length, _ in length * DesignTokens.Layout.exploreContentFraction }
                mapPane
            }
        }
    }

    /// The button floats inside the safe area, so it sits above the floating tab bar rather than under it.
    private func withCreateButton(_ content: some View) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            CreateMenuButton(onCreateGame: { presentForUser(.createGame) },
                             onCreateGroup: { presentForUser(.createGroup) },
                             onCreateTournament: { presentForUser(.createTournament) })
                .padding(DesignTokens.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The map beside the content column: always there, nothing floating over it, its selected card at its own bottom.
    private var mapPane: some View {
        EventsMapView(viewModel: viewModel)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.exploreMapPane)
    }
}
