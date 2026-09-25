import SwiftUI

/// The form for a new group: Cancel and Create in the bar, the fields below; the visibility is chosen here and fixed.
struct CreateGroupSheet: View {
    let viewModel: CreateGroupViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        GroupDraftSheet(viewModel: viewModel,
                        title: AppBranding.Groups.Create.title,
                        submitTitle: AppBranding.Groups.Create.submit,
                        allowsVisibilityChoice: true,
                        errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    CreateGroupSheet(viewModel: dependencies.makeCreateGroupViewModel { _ in }, errorCenter: dependencies.errorCenter)
}
