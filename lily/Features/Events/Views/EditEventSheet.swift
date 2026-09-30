import SwiftUI

/// The host's game in the event form: Cancel and Save in the bar. Closes itself once the backend answered.
struct EditEventSheet: View {
    let viewModel: EditEventViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        EventDraftSheet(viewModel: viewModel,
                        title: AppBranding.Events.Edit.title,
                        submitTitle: AppBranding.Events.Edit.save,
                        errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    EditEventSheet(viewModel: dependencies.makeEditEventViewModel(for: MockEventFixtures.make(now: .now, count: 1)[0]) { _ in },
                   errorCenter: dependencies.errorCenter)
}
