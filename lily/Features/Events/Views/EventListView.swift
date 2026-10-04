import SwiftUI

/// The Explore screen: a list, switchable to a map, narrowable through a filter panel dropped down from the toolbar,
/// with a floating button that creates a game and a header (the groups carousel) above the list.
struct EventListView<Header: View>: View {
    let title: String
    let emptyState: EmptyStateView
    /// Heading over the cards, for a screen whose header (the groups carousel) would otherwise make them read as its.
    let listTitle: String?
    let showsMap: Bool
    let filterable: Bool
    /// Floats the "+" menu over the content. A signed-in user gets the game or group form, a guest the sign-in sheet.
    let creatable: Bool
    private let dependencies: AppDependencies
    private let header: () -> Header
    /// Pull-to-refresh reloads the header's content too (the carousel), before the events.
    private let refreshHeader: () async -> Void
    @State private var presentation: EventsPresentation = .list
    @State private var viewModel: EventListViewModel
    @State private var presentedSheet: ExploreSheet?

    private enum ExploreSheet: String, Identifiable {
        case createGame, createGroup, createTournament, signIn

        var id: String { rawValue }
    }
    @Environment(\.scenePhase) private var scenePhase

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
                creatableContent
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(presentation == .map ? .inline : .large)
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
                if showsMap {
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
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .createGame:
                // The created event lands in this list at once; sibling lists learn of it through `add`.
                CreateEventSheet(viewModel: dependencies.makeCreateEventViewModel(onCreated: viewModel.add),
                                 errorCenter: dependencies.errorCenter)
            case .createGroup:
                // The founder lands in the new group (on Home, where groups live); the carousel and Home learn of it
                // through `groupChanges` and the store.
                CreateGroupSheet(viewModel: dependencies.makeCreateGroupViewModel { dependencies.navigation.open(group: $0) },
                                 errorCenter: dependencies.errorCenter)
            case .createTournament:
                // The organiser lands in the new tournament (on Home, where theirs live); the carousel and Home learn
                // of it through `tournamentChanges`.
                CreateTournamentSheet(viewModel: dependencies.makeCreateTournamentViewModel { detail in
                    dependencies.tournamentChanges.recordChange()
                    dependencies.navigation.open(tournament: detail.tournament.destination)
                }, errorCenter: dependencies.errorCenter)
            case .signIn:
                SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            }
        }
    }

    /// The button floats inside the safe area, so it sits above the floating tab bar rather than under it.
    @ViewBuilder
    private var creatableContent: some View {
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

    /// Only a signed-in user can host or found; a guest is offered sign-in, and comes back to the menu afterwards.
    private func presentForUser(_ sheet: ExploreSheet) {
        if dependencies.sessionController.state.user != nil {
            presentedSheet = sheet
        } else {
            dependencies.logger.info(.auth, "Guest asked to create from Explore; showing sign-in")
            presentedSheet = .signIn
        }
    }

    private var presentationPicker: some View {
        Picker(AppBranding.Events.presentationPicker, selection: $presentation) {
            ForEach(EventsPresentation.allCases, id: \.self) { option in
                Label(option.title, systemImage: option.symbolName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsPresentation)
    }

    /// In map mode the map is the screen whatever the list would say: the user's surroundings, with the pins that
    /// match. The list's states sit under the header.
    @ViewBuilder
    private var content: some View {
        if showsMap, presentation == .map {
            EventsMapView(viewModel: viewModel, bottomInset: creatable ? DesignTokens.Layout.floatingButtonFootprint : 0)
        } else if viewModel.isInitialLoad {
            refreshableScroll { stateSlot { ProgressView() } }
        } else if viewModel.events.isEmpty {
            refreshableScroll { stateSlot { viewModel.loadFailed ? loadFailedState : emptyState } }
        } else if viewModel.isEverythingFilteredOut {
            refreshableScroll { stateSlot { filteredOutState } }
        } else {
            refreshableScroll { eventList }
        }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let listTitle {
                SectionTitle(text: listTitle)
            }
            EventCardList(events: viewModel.visibleEvents, distance: viewModel.distanceText)
        }
        // With the create button floating over the corner, the last card scrolls clear of it.
        .padding(.bottom, creatable ? DesignTokens.Layout.floatingButtonFootprint : DesignTokens.Spacing.xxl)
    }

    /// The defaults alone (10 km) can hide every event while nothing is "active", so the way out widens to everything.
    private var filteredOutState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.filter,
                       title: AppBranding.Events.Filter.emptyTitle,
                       message: AppBranding.Events.Filter.emptyMessage,
                       actionTitle: AppBranding.Events.Filter.showAll,
                       action: viewModel.showEverything)
    }

    private var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: AppBranding.Events.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }

    /// A spinner or an empty state centred in most of the screen, so it reads as the screen's state while the
    /// header above stays in view (a full-height frame would push it below the fold).
    private func stateSlot(@ViewBuilder _ state: () -> some View) -> some View {
        state()
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in length * DesignTokens.Layout.stateSlotHeightFraction }
    }

    /// The header above whatever the list shows; pull-to-refresh reloads both.
    private func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        RefreshableScroll {
            await refreshHeader()
            await viewModel.load()
        } content: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                header()
                content()
            }
        }
    }
}
