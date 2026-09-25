import SwiftUI

/// The settings of an existing group: Save is enabled once something differs; the visibility cannot change.
struct EditGroupSheet: View {
    let viewModel: EditGroupViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        GroupDraftSheet(viewModel: viewModel,
                        title: AppBranding.Groups.Create.editTitle,
                        submitTitle: AppBranding.Groups.Create.save,
                        allowsVisibilityChoice: false,
                        errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    EditGroupSheet(viewModel: dependencies.makeEditGroupViewModel(for: MockGroupFixtures.make(now: .now)[2]) { _ in },
                   errorCenter: dependencies.errorCenter)
}
