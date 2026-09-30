import SwiftUI

/// The create form in a sheet: Cancel and Create in the bar, the fields below. Closes itself once the backend answered.
struct CreateEventSheet: View {
    let viewModel: CreateEventViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        EventDraftSheet(viewModel: viewModel,
                        title: AppBranding.Events.Create.title,
                        submitTitle: AppBranding.Events.Create.submit,
                        errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    CreateEventSheet(viewModel: dependencies.makeCreateEventViewModel { _ in }, errorCenter: dependencies.errorCenter)
}
