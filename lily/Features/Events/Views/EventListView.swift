import SwiftUI

/// One screen for Explore and My Events: a list, optionally switchable to a map, narrowable through a filter panel
/// dropped down from the toolbar, and optionally with a floating button that creates a game.
struct EventListView: View {
    let title: String
    let emptyState: EmptyStateView
    let showsMap: Bool
    let filterable: Bool
    /// Floats the create button over the content. A signed-in user gets the create sheet, a guest the sign-in sheet.
    let creatable: Bool
    private let dependencies: AppDependencies
    @State private var presentation: EventsPresentation = .list
    @State private var viewModel: EventListViewModel
    @State private var isCreatePresented = false
    @State private var isSignInPresented = false
    @Environment(\.scenePhase) private var scenePhase

    init(title: String,
         emptyState: EmptyStateView,
         showsMap: Bool = false,
         filterable: Bool = false,
         creatable: Bool = false,
         scope: EventScope,
         dependencies: AppDependencies) {
        self.title = title
        self.emptyState = emptyState
        self.showsMap = showsMap
        self.filterable = filterable
        self.creatable = creatable
        self.dependencies = dependencies
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
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: viewModel.replace))
            }
            // An event's "Hosted in" link pushes its group here, so every stack knows the group screens.
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
        .task { await viewModel.loadIfStale() }
        .task { await viewModel.loadUserLocation() }
        .onChange(of: presentation) { viewModel.presentationChanged(to: presentation) }
        // Coming back to the foreground is the one moment location permission may have changed (Settings), and the
        // user may have moved meanwhile, so the position is asked for again; the cache answers within its TTL.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await viewModel.refreshUserLocation() } }
        }
        .sheet(isPresented: $isCreatePresented) {
            // The created event lands in this list at once; sibling lists learn of it through `add`.
            CreateEventSheet(viewModel: dependencies.makeCreateEventViewModel(onCreated: viewModel.add),
                             errorCenter: dependencies.errorCenter)
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
        }
    }

    /// The button floats inside the safe area, so it sits above the floating tab bar rather than under it.
    @ViewBuilder
    private var creatableContent: some View {
        if creatable {
            ZStack(alignment: .bottomTrailing) {
                content
                CreateEventButton(action: presentCreate)
                    .padding(DesignTokens.Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
        }
    }

    /// Only a signed-in user can host; a guest is offered sign-in, and comes back to the button afterwards.
    private func presentCreate() {
        if dependencies.sessionController.state.user != nil {
            isCreatePresented = true
        } else {
            dependencies.logger.info(.auth, "Guest asked to create a game; showing sign-in")
            isSignInPresented = true
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isInitialLoad {
            ProgressView()
        } else if viewModel.events.isEmpty {
            // Scrollable so the "pull to refresh" the error copy promises is possible from here.
            refreshableScroll {
                (viewModel.loadFailed ? loadFailedState : emptyState)
                    .containerRelativeFrame(.vertical)
            }
        } else if viewModel.isEverythingFilteredOut {
            refreshableScroll { filteredOutState.containerRelativeFrame(.vertical) }
        } else if presentation == .map {
            EventsMapView(viewModel: viewModel, bottomInset: creatable ? DesignTokens.Layout.floatingButtonFootprint : 0)
        } else {
            refreshableScroll { eventList }
        }
    }

    private var eventList: some View {
        EventCardList(events: viewModel.visibleEvents, distance: viewModel.distanceText)
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

    /// The one place that declares the pull-to-refresh gesture and what it reloads.
    private func refreshableScroll(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView { content() }
            .refreshable { await viewModel.load() }
    }
}
