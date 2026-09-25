import SwiftUI

/// The sheet a tapped invite link (or `-open-invite`) opens over the root: the preview, then the join.
struct InvitePreviewSheet: View {
    @State private var viewModel: InvitePreviewViewModel
    private let dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    init(viewModel: InvitePreviewViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                InvitePreviewContent(viewModel: viewModel, dependencies: dependencies) { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .errorPopup(dependencies.errorCenter)
        .task { await viewModel.load() }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let code = InviteCode(AppConfig.Groups.mockInviteCode)!
    InvitePreviewSheet(viewModel: dependencies.makeInvitePreviewViewModel(code: code) { _ in }, dependencies: dependencies)
}
