import SwiftUI

/// A group reached through a reference (an event's "Hosted in" badge): fetched first, then shown as the detail; gone
/// groups get the "no longer available" state, other failures a retry.
struct GroupLoaderView: View {
    @State private var viewModel: GroupLoaderViewModel
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Groups

    init(viewModel: GroupLoaderViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ContentScreen { ProgressView() }
            case .loaded(let group):
                GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: group, context: .standalone) { _ in },
                                dependencies: dependencies)
            case .notFound:
                ContentScreen {
                    EmptyStateView(symbolName: DesignTokens.Symbols.groups,
                                   title: Copy.unavailable,
                                   message: Copy.unavailableMessage)
                }
            case .failed:
                ContentScreen {
                    EmptyStateView(symbolName: DesignTokens.Symbols.error,
                                   title: Copy.loadFailedTitle,
                                   message: Copy.loadFailedMessage,
                                   actionTitle: Copy.tryAgain) {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        GroupLoaderView(viewModel: dependencies.makeGroupLoaderViewModel(ref: MockGroupFixtures.make(now: .now)[0].ref),
                        dependencies: dependencies)
    }
}
