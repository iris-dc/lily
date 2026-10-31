import SwiftUI

/// The sheets Explore presents (the create forms and sign-in) and the content states of the list, apart from the
/// screen's composition in `EventListView.swift`, which is at SwiftLint's type-body limit.
extension EventListView {
    /// The sheet for one `ExploreSheet` case.
    @ViewBuilder
    func sheetContent(for sheet: ExploreSheet) -> some View {
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

    /// Explore owns the create sheets, so this is where a shortcut's intent is taken; `CreateIntentPolicy` decides.
    func consumePendingCreate() {
        let navigation = dependencies.navigation
        let decision = CreateIntentPolicy.decide(intent: navigation.pendingCreate,
                                                 presentedSheet: presentedSheet,
                                                 isSignedIn: dependencies.sessionController.state.isSignedIn)
        guard decision.consumes else { return }
        navigation.pendingCreate = nil
        if let sheet = decision.present {
            present(sheet)
        } else {
            dependencies.logger.debug(.ui, "Create shortcut dropped: a sheet is already up")
        }
    }

    /// The "+" menu's request: the form for a signed-in user, sign-in for a guest.
    func presentForUser(_ requested: ExploreSheet) {
        present(CreateIntentPolicy.sheet(for: requested, isSignedIn: dependencies.sessionController.state.isSignedIn))
    }

    /// `.signIn` is only ever the guest's substitute, so presenting it is the moment the guest's ask is logged.
    private func present(_ sheet: ExploreSheet) {
        if sheet == .signIn {
            dependencies.logger.info(.auth, "Guest asked to create from Explore; showing sign-in")
        }
        presentedSheet = sheet
    }

    var presentationPicker: some View {
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
    /// match. Otherwise the list, whose states sit under the header.
    @ViewBuilder
    var content: some View {
        if showsMapAlone {
            EventsMapView(viewModel: viewModel, bottomInset: DesignTokens.Layout.floatingButtonFootprint)
        } else {
            listContent
        }
    }

    /// Each state in a `refreshableScroll` of its own, so a state change starts the scroll afresh.
    @ViewBuilder
    var listContent: some View {
        switch screenState {
        case .loading: refreshableScroll { stateSlot { ProgressView() } }
        case .failed: refreshableScroll { stateSlot { loadFailedState } }
        case .empty: refreshableScroll { stateSlot { emptyState } }
        case .filteredOut: refreshableScroll { stateSlot { filteredOutState } }
        case .list: refreshableScroll { eventList }
        }
    }

    var screenState: EventListScreenState {
        .resolve(isInitialLoad: viewModel.isInitialLoad,
                 loadFailed: viewModel.loadFailed,
                 hasEvents: !viewModel.events.isEmpty,
                 isEverythingFilteredOut: viewModel.isEverythingFilteredOut,
                 awaitsAnswerForPosition: viewModel.awaitsAnswerForPosition)
    }

    var eventList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let listTitle {
                SectionTitle(text: listTitle)
            }
            EventCardList(events: viewModel.visibleEvents, distance: viewModel.distanceText)
        }
        // With the create button floating over the corner, the last card scrolls clear of it.
        .padding(.bottom, DesignTokens.Layout.floatingButtonFootprint)
    }

    /// The defaults alone (10 km) can hide every event while nothing is "active", so the way out widens to everything.
    var filteredOutState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.filter,
                       title: AppBranding.Events.Filter.emptyTitle,
                       message: AppBranding.Events.Filter.emptyMessage,
                       actionTitle: AppBranding.Events.Filter.showAll,
                       action: viewModel.showEverything)
    }

    var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: AppBranding.Events.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }

    var emptyState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.explore,
                       title: AppBranding.exploreEmptyTitle,
                       message: AppBranding.exploreEmptyMessage)
    }

    /// A spinner or an empty state centred in what the screen leaves under the header, so it reads as the screen's
    /// state with the header in view and clear of the tab bar at rest (a fixed share of the screen runs under the bar
    /// once the header is tall). The clear colour is the floor: a state taller than the room left (a tall header on a
    /// short phone) keeps its own height and scrolls into view.
    func stateSlot(@ViewBuilder _ state: () -> some View) -> some View {
        ZStack {
            Color.clear.containerRelativeFrame(.vertical) { length, _ in max(0, length - headerFootprint) }
            state().readableColumn()
        }
    }

    /// The header's height plus the stack's spacing under it; nothing while the header shows nothing.
    private var headerFootprint: CGFloat {
        headerHeight > 0 ? headerHeight + DesignTokens.Spacing.xl : 0
    }

    /// The header above whatever the list shows; pull-to-refresh reloads both.
    func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                header()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                content()
            }
        }
        .refreshable {
            await refreshHeader()
            await viewModel.load()
        }
    }
}
