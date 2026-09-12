import SwiftUI

/// One screen for Explore and My Events: a list, optionally switchable to a map and narrowable through a filter panel dropped down from the toolbar.
struct EventListView: View {
    let title: String
    let emptyState: EmptyStateView
    let showsMap: Bool
    let filterable: Bool
    private let dependencies: AppDependencies
    @State private var presentation: EventsPresentation = .list
    @State private var viewModel: EventListViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(title: String,
         emptyState: EmptyStateView,
         showsMap: Bool = false,
         filterable: Bool = false,
         scope: EventScope,
         dependencies: AppDependencies) {
        self.title = title
        self.emptyState = emptyState
        self.showsMap = showsMap
        self.filterable = filterable
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeEventListViewModel(scope: scope))
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(presentation == .map ? .inline : .large)
            .navigationDestination(for: SportEvent.self) { event in
                // A join or leave on the detail comes back through `replace`, so this list is right on return.
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event, onChange: viewModel.replace))
            }
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
        // Coming back to the foreground is the one moment location permission may have changed (Settings), so a
        // missing position is asked for again; a known one is kept. Foregrounding is rare, so this is cheap.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await viewModel.retryUserLocationIfMissing() } }
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
            EventsMapView(viewModel: viewModel)
        } else {
            refreshableScroll { eventList }
        }
    }

    private var eventList: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(viewModel.visibleEvents) { event in
                NavigationLink(value: event) {
                    EventCard(event: event, distance: viewModel.distanceText(for: event))
                }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.bottom, DesignTokens.Spacing.xxl)
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

/// List or map, as chosen in the toolbar.
nonisolated enum EventsPresentation: CaseIterable, Hashable, Sendable {
    case list, map

    var title: String {
        switch self {
        case .list: AppBranding.Events.listPresentation
        case .map: AppBranding.Events.mapPresentation
        }
    }

    var symbolName: String {
        switch self {
        case .list: DesignTokens.Symbols.list
        case .map: DesignTokens.Symbols.map
        }
    }
}
