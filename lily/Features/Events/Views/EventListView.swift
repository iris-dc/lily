import SwiftUI

/// One list for Explore, My Events and Search. Behaviour differs only by scope and copy.
struct EventListView: View {
    let title: String
    let subtitle: String?
    let emptyState: EmptyStateView
    let searchable: Bool
    @State private var viewModel: EventListViewModel

    init(title: String,
         subtitle: String? = nil,
         emptyState: EmptyStateView,
         searchable: Bool = false,
         viewModel: EventListViewModel) {
        self.title = title
        self.subtitle = subtitle
        self.emptyState = emptyState
        self.searchable = searchable
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: DesignTokens.Opacity.faint)
                content
            }
            .navigationTitle(title)
            .navigationDestination(for: SportEvent.self) { EventDetailView(event: $0) }
            .searchableIfNeeded(searchable, text: $viewModel.searchText)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.events.isEmpty {
            ProgressView()
        } else if viewModel.filteredEvents.isEmpty {
            emptyState
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
                        NavigationLink(value: event) { EventCard(event: event) }
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
