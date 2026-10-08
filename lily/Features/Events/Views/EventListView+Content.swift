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

    /// Explore alone presents the create sheets, so only the creatable list takes the intent.
    func consumePendingCreate() {
        guard creatable, let intent = dependencies.navigation.pendingCreate else { return }
        dependencies.navigation.pendingCreate = nil
        // ⌘N inside the create form (or any sheet of this screen) must not replace it and lose what was typed.
        guard presentedSheet == nil else { return }
        presentForUser(ExploreSheet(intent))
    }

    /// Only a signed-in user can host or found; a guest is offered sign-in, and comes back to the menu afterwards.
    func presentForUser(_ sheet: ExploreSheet) {
        if dependencies.sessionController.state.user != nil {
            presentedSheet = sheet
        } else {
            dependencies.logger.info(.auth, "Guest asked to create from Explore; showing sign-in")
            presentedSheet = .signIn
        }
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
            EventsMapView(viewModel: viewModel, bottomInset: creatable ? DesignTokens.Layout.floatingButtonFootprint : 0)
        } else {
            listContent
        }
    }

    @ViewBuilder
    var listContent: some View {
        if viewModel.isInitialLoad {
            refreshableScroll { stateSlot { ProgressView() } }
        } else if viewModel.events.isEmpty {
            refreshableScroll { stateSlot { viewModel.loadFailed ? loadFailedState : emptyState } }
        } else if viewModel.isEverythingFilteredOut {
            refreshableScroll { stateSlot { filteredOutState } }
        } else {
            refreshableScroll { eventList }
        }
    }

    var eventList: some View {
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

    /// A spinner or an empty state centred in most of the screen, so it reads as the screen's state while the
    /// header above stays in view (a full-height frame would push it below the fold).
    func stateSlot(@ViewBuilder _ state: () -> some View) -> some View {
        state()
            .readableColumn()
            .containerRelativeFrame(.vertical) { length, _ in length * DesignTokens.Layout.stateSlotHeightFraction }
    }

    /// The header above whatever the list shows; pull-to-refresh reloads both.
    func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
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
