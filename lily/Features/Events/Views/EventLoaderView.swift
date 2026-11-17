import SwiftUI

/// An event reached by id and name alone (an event room's info button): fetched first, then shown as the detail; gone
/// events get the "no longer available" state, other failures a retry. `GroupLoaderView`'s pattern.
struct EventLoaderView: View {
    @State private var viewModel: EventLoaderViewModel
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Events

    init(viewModel: EventLoaderViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ContentScreen { ProgressView() }
            case .loaded(let event):
                // The lists behind reload on the change tracker, like the Chats stack's own `SportEvent` destination.
                EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: event) { _ in
                    dependencies.eventChanges.recordChange()
                }, dependencies: dependencies)
            case .notFound:
                ContentScreen {
                    EmptyStateView(symbolName: DesignTokens.Symbols.game,
                                   title: Copy.unavailable,
                                   message: AppBranding.Groups.unavailableMessage)
                }
            case .failed:
                ContentScreen {
                    EmptyStateView.loadFailed(title: Copy.detailLoadFailedTitle,
                                              message: AppBranding.Groups.loadFailedMessage,
                                              actionTitle: AppBranding.Groups.tryAgain) {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let destination = EventDestination(id: "mock-event-0", name: "Sunset 5-a-side")
    NavigationStack {
        EventLoaderView(viewModel: dependencies.makeEventLoaderViewModel(for: destination), dependencies: dependencies)
    }
}
