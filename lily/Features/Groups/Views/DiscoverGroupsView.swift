import SwiftUI

/// Every public group, pushed from the carousel's "See all": a search field that is always shown, a type dropdown
/// in the toolbar, and the paged cards. Works for guests; a card opens the group's detail.
struct DiscoverGroupsView: View {
    @State private var viewModel: GroupListViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeGroupListViewModel(scope: .discover))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ContentScreen {
            DiscoverGroupList(viewModel: viewModel)
        }
        .navigationTitle(AppBranding.Groups.discoverTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: AppBranding.Groups.discover)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { GroupTypeFilterButton(viewModel: viewModel) }
        }
        .task { await viewModel.loadIfStale() }
        .onDisappear { viewModel.cancel() }
    }
}

#Preview {
    NavigationStack {
        DiscoverGroupsView(dependencies: .makeMock())
    }
}
