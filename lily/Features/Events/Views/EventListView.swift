import SwiftUI

/// The Explore screen: a list, switchable to a map, narrowable through a filter panel dropped down from the toolbar,
/// with a floating button that creates a game and a header (the groups carousel) above the list. On a wide window
/// (`LayoutMode.wide`) the map is not a mode but a pane: the content column on the left, the map always on the right,
/// and the picker gone (`EventListLayout`).
struct EventListView<Header: View>: View {
    let title: String
    let emptyState: EmptyStateView
    /// Heading over the cards, for a screen whose header (the groups carousel) would otherwise make them read as its.
    let listTitle: String?
    let showsMap: Bool
    let filterable: Bool
    /// Floats the "+" menu over the content. A signed-in user gets the game or group form, a guest the sign-in sheet.
    let creatable: Bool
    let dependencies: AppDependencies
    let header: () -> Header
    /// Pull-to-refresh reloads the header's content too (the carousel), before the events.
    let refreshHeader: () async -> Void
    @State var presentation: EventsPresentation = .list
    @State var viewModel: EventListViewModel
    @State var presentedSheet: ExploreSheet?

    enum ExploreSheet: String, Identifiable {
        case createGame, createGroup, createTournament, signIn

        var id: String { rawValue }

        /// The sheet a keyboard shortcut's intent asks for.
        init(_ intent: CreateIntent) {
            switch intent {
            case .game: self = .createGame
            case .group: self = .createGroup
            case .tournament: self = .createTournament
            }
        }
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutMode) private var layoutMode

    private var layout: EventListLayout { .resolve(mode: layoutMode, showsMap: showsMap) }
    /// Whether the map is the whole content right now: the switchable layout with the picker on "Map".
    var showsMapAlone: Bool { layout == .switchable && showsMap && presentation == .map }

    init(title: String,
         emptyState: EmptyStateView,
         listTitle: String? = nil,
         showsMap: Bool = false,
         filterable: Bool = false,
         creatable: Bool = false,
         scope: EventScope,
         dependencies: AppDependencies,
         refreshHeader: @escaping () async -> Void = {},
         @ViewBuilder header: @escaping () -> Header) {
        self.title = title
        self.emptyState = emptyState
        self.listTitle = listTitle
        self.showsMap = showsMap
        self.filterable = filterable
        self.creatable = creatable
        self.dependencies = dependencies
        self.header = header
        self.refreshHeader = refreshHeader
        _viewModel = State(initialValue: dependencies.makeEventListViewModel(scope: scope))
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                screen
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(showsMapAlone ? .inline : .large)
            .navigationDestination(for: SportEvent.self) { event in
                // A join or leave on the detail comes back through `replace`, so this list is right on return.
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: viewModel.replace),
                                dependencies: dependencies)
            }
            // An event's "Hosted in" link and the carousel push groups here, so every stack knows the group screens.
            .groupDestinations(dependencies: dependencies)
            .toolbar {
                if filterable {
                    ToolbarItem(placement: .topBarTrailing) { EventFilterButton(viewModel: viewModel) }
                }
                if showsMap, layout == .switchable {
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
            creatable(content)
        case .sideBySide:
            HStack(spacing: 0) {
                creatable(listContent)
                    .containerRelativeFrame(.horizontal) { length, _ in length * DesignTokens.Layout.exploreContentFraction }
                mapPane
            }
        }
    }

    /// The button floats inside the safe area, so it sits above the floating tab bar rather than under it.
    @ViewBuilder
    private func creatable(_ content: some View) -> some View {
        if creatable {
            ZStack(alignment: .bottomTrailing) {
                content
                CreateMenuButton(onCreateGame: { presentForUser(.createGame) },
                                 onCreateGroup: { presentForUser(.createGroup) },
                                 onCreateTournament: { presentForUser(.createTournament) })
                    .padding(DesignTokens.Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
        }
    }

    /// The map beside the content column: always there, nothing floating over it, its selected card at its own bottom.
    private var mapPane: some View {
        EventsMapView(viewModel: viewModel)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.exploreMapPane)
    }
}
