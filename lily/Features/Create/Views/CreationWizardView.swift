import SwiftUI

/// The creation wizard's shell: a `NavigationStack` whose root is the kind page when the policy shows one and the
/// first step otherwise, with every Next pushing the next step. The kind pick is one-way — a kind's first step hides
/// the system back button (which also disables the pop gesture), so back stops there and the kind page cannot be
/// revisited within the attempt. Cancel asks before discarding a draft the user edited and closes silently
/// otherwise; close, paging back and interactive dismissal are locked while a submit is in flight; the error popup is mounted
/// here, and the view dismisses itself once the view model reports done. Presentation-agnostic: the presenting
/// screen chooses cover or sheet.
struct CreationWizardView<EventModel: EventDraftEditing>: View {
    @State private var model: CreationWizardModel<EventModel>
    private let errorCenter: ErrorCenter
    @State private var isConfirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Create

    init(model: CreationWizardModel<EventModel>, errorCenter: ErrorCenter) {
        _model = State(initialValue: model)
        self.errorCenter = errorCenter
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            root
                .navigationDestination(for: CreationStep.self) { step in
                    stepPage(for: step)
                }
        }
        .tint(Color.lilyAccent)
        .errorPopup(errorCenter)
        // A dirty draft is never swiped away silently: the swipe is refused, so the discard question stays reachable
        // only through Cancel; while a submit is out its outcome must never be unknown, as on every writing sheet.
        .interactiveDismissDisabled(model.isSubmitting || model.isDirty)
        .task(id: model.kind) { await model.prepare() }
        .onChange(of: model.draft) { model.noteDraftChanged() }
        .onChange(of: model.isDone) {
            if model.isDone { dismiss() }
        }
        .confirmationDialog(Copy.discardTitle, isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button(Copy.discard, role: .destructive) { dismiss() }
            // Plain role on purpose: the centered dialog adds no automatic Cancel and swallows a `.cancel`-role
            // button, which would leave the destructive Discard as the only visible way out.
            Button(Copy.keepEditing) {}
        }
    }

    @ViewBuilder private var root: some View {
        if model.opening.showsKindPage {
            CreationKindPage(model: model, onCancel: requestClose)
        } else if let first = model.steps.first {
            stepPage(for: first)
        }
    }

    @ViewBuilder
    private func stepPage(for step: CreationStep) -> some View {
        switch step {
        case .event(let eventStep):
            if let viewModel = model.eventModel {
                eventPage(eventStep, viewModel: viewModel)
                    // The one-way mechanism: back stops at the kind's first step, pushed or root alike. Hiding the
                    // back button while a submit is out also disables the pop gesture (the locked-while-busy contract).
                    .navigationBarBackButtonHidden(model.steps.first == step || model.isSubmitting)
            }
        case .eventMap:
            if let viewModel = model.eventModel {
                LocationPickerView(coordinate: spotBinding(for: viewModel))
            }
        }
    }

    /// A spot from the map picker is the user's choice (`EventDraft.pickSpot`).
    private func spotBinding(for viewModel: EventModel) -> Binding<Coordinate?> {
        Binding(get: { viewModel.draft.coordinate }, set: { viewModel.draft.pickSpot($0) })
    }

    @ViewBuilder
    private func eventPage(_ step: CreationStep.EventStep, viewModel: EventModel) -> some View {
        switch step {
        case .name: EventNamePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .type: EventTypePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .when: EventWhenPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .group: EventGroupPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .place: EventPlacePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .players: EventPlayersPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .details: EventDetailsPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        }
    }

    private func requestClose() {
        guard !model.isSubmitting else { return }
        if model.isDirty {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    CreationWizardView(model: dependencies.makeCreationWizardModel(seed: .empty) { _ in },
                       errorCenter: dependencies.errorCenter)
}
