import SwiftUI

/// The creation wizard's shell: a `NavigationStack` whose root is the seeded kind's first step — the "+" menu and
/// every other entry point name the kind, so there is no kind page (the owner's third design round, 2026-11-11) —
/// with every Next pushing the next step. Cancel asks before discarding a draft the user edited and closes silently
/// otherwise; close, paging back and interactive dismissal are locked while a submit is in flight; the error popup is
/// mounted here, and the view dismisses itself once the view model reports done. Presentation-agnostic: the
/// presenting screen chooses cover or sheet. The shell draws the flow's one `ContentScreen` aurora under the stack;
/// the step pages render transparent content over it, so a push never composites two live auroras (the third
/// round's performance pass — each pushed page used to carry its own full aurora and grain).
struct CreationWizardView<EventModel: EventDraftEditing,
                          GroupModel: GroupDraftEditing,
                          TournamentModel: TournamentDraftEditing>: View {
    @State private var model: CreationWizardModel<EventModel, GroupModel, TournamentModel>
    private let errorCenter: ErrorCenter
    @State private var isConfirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Create

    init(model: CreationWizardModel<EventModel, GroupModel, TournamentModel>, errorCenter: ErrorCenter) {
        _model = State(initialValue: model)
        self.errorCenter = errorCenter
    }

    var body: some View {
        @Bindable var model = model
        ContentScreen {
            NavigationStack(path: $model.path) {
                root
                    .navigationDestination(for: CreationStep.self) { step in
                        stepPage(for: step)
                    }
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
        if let first = model.steps.first {
            stepPage(for: first)
        }
    }

    @ViewBuilder
    private func stepPage(for step: CreationStep) -> some View {
        switch step {
        case .event(let eventStep): eventStepPage(eventStep)
        case .group(let groupStep): groupStepPage(groupStep)
        case .tournament(let tournamentStep): tournamentStepPage(tournamentStep)
        case .eventMap: mapPage(for: model.eventModel, draft: \.draft)
        case .groupMap: mapPage(for: model.groupModel, draft: \.draft)
        case .tournamentMap: mapPage(for: model.tournamentModel, draft: \.draft)
        }
    }

    /// Hiding the back button while a submit is out also disables the pop gesture (the locked-while-busy contract).
    /// The one-way kind rule needs nothing here any more: the kind's first step is the stack root.
    private var hidesBack: Bool { model.isSubmitting }

    @ViewBuilder private func eventStepPage(_ step: CreationStep.EventStep) -> some View {
        if let viewModel = model.eventModel {
            eventPage(step, viewModel: viewModel)
                .navigationBarBackButtonHidden(hidesBack)
        }
    }

    @ViewBuilder private func groupStepPage(_ step: CreationStep.GroupStep) -> some View {
        if let viewModel = model.groupModel {
            groupPage(step, viewModel: viewModel)
                .navigationBarBackButtonHidden(hidesBack)
        }
    }

    @ViewBuilder private func tournamentStepPage(_ step: CreationStep.TournamentStep) -> some View {
        if let viewModel = model.tournamentModel {
            tournamentPage(step, viewModel: viewModel)
                .navigationBarBackButtonHidden(hidesBack)
        }
    }

    /// One map page for every kind: the picker over the kind's draft, shown while its view model exists. A spot
    /// from the map picker is the user's choice (`PlacePickingDraft.pickSpot`), whatever the kind. The picker draws
    /// no background of its own here and the navigation container is cleared like the step pages', so the shell's
    /// one aurora shows through the map push too.
    @ViewBuilder
    private func mapPage<Model: AnyObject, Draft: PlacePickingDraft>(
        for viewModel: Model?, draft: ReferenceWritableKeyPath<Model, Draft>) -> some View {
        if let viewModel {
            LocationPickerView(coordinate: Binding(get: { viewModel[keyPath: draft].coordinate },
                                                   set: { viewModel[keyPath: draft].pickSpot($0) }),
                               drawsBackground: false)
                .containerBackground(Color.clear, for: .navigation)
        }
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

    @ViewBuilder
    private func groupPage(_ step: CreationStep.GroupStep, viewModel: GroupModel) -> some View {
        switch step {
        case .name: GroupNamePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .description: GroupDescriptionPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .type: GroupTypePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .visibility: GroupVisibilityPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .place: GroupPlacePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .permissions: GroupPermissionsPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        }
    }

    @ViewBuilder
    private func tournamentPage(_ step: CreationStep.TournamentStep, viewModel: TournamentModel) -> some View {
        switch step {
        case .name: TournamentNamePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .type: TournamentTypePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .format: TournamentFormatPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .schedule: TournamentSchedulePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .group: TournamentGroupPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .place: TournamentPlacePage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .entries: TournamentEntriesPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .whoMayJoin: TournamentWhoPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
        case .details: TournamentDetailsPage(wizard: model, viewModel: viewModel, onCancel: requestClose)
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
    CreationWizardView(model: dependencies.makeCreationWizardModel(seed: .empty,
                                                                   onCreatedEvent: { _ in },
                                                                   onCreatedGroup: { _ in },
                                                                   onCreatedTournament: { _ in }),
                       errorCenter: dependencies.errorCenter)
}
