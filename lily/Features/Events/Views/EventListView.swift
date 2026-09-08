import SwiftUI

/// One screen for Explore, My Events and Search: a list, optionally switchable to a map.
struct EventListView: View {
    let title: String
    let subtitle: String?
    let emptyState: EmptyStateView
    let searchable: Bool
    let showsMap: Bool
    @State private var presentation: EventsPresentation = .list
    @State private var viewModel: EventListViewModel

    init(title: String,
         subtitle: String? = nil,
         emptyState: EmptyStateView,
         searchable: Bool = false,
         showsMap: Bool = false,
         viewModel: EventListViewModel) {
        self.title = title
        self.subtitle = subtitle
        self.emptyState = emptyState
        self.searchable = searchable
        self.showsMap = showsMap
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: DesignTokens.Opacity.faint)
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(presentation == .map ? .inline : .large)
            .navigationDestination(for: SportEvent.self) { EventDetailView(event: $0) }
            .searchableIfNeeded(searchable, text: $viewModel.searchText)
            .toolbar {
                if showsMap {
                    // iOS 26 gives every toolbar item its own glass; the segmented picker already draws one.
                    ToolbarItem(placement: .topBarTrailing) { presentationPicker }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
        }
        .task { await viewModel.load() }
        .task { await viewModel.loadUserLocation() }
    }

    private var presentationPicker: some View {
        Picker("View", selection: $presentation) {
            ForEach(EventsPresentation.allCases, id: \.self) { option in
                Label(option.title, systemImage: option.symbolName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier("events-presentation")
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.events.isEmpty {
            ProgressView()
        } else if viewModel.filteredEvents.isEmpty {
            emptyState
        } else if presentation == .map {
            EventsMapView(viewModel: viewModel)
        } else {
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.md) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(viewModel.filteredEvents) { event in
                        NavigationLink(value: event) {
                            EventCard(event: event, distance: viewModel.distanceText(for: event))
                        }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xxl)
            }
            .refreshable { await viewModel.load() }
        }
    }
}

private extension View {
    @ViewBuilder
    func searchableIfNeeded(_ enabled: Bool, text: Binding<String>) -> some View {
        if enabled {
            searchable(text: text, prompt: "Sport, place or title")
        } else {
            self
        }
    }
}

/// List or map, as chosen in the toolbar.
nonisolated enum EventsPresentation: CaseIterable, Hashable, Sendable {
    case list, map

    var title: String {
        switch self {
        case .list: "List"
        case .map: "Map"
        }
    }

    var symbolName: String {
        switch self {
        case .list: DesignTokens.Symbols.list
        case .map: DesignTokens.Symbols.map
        }
    }
}
