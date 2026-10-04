import SwiftUI

/// What a sheet over `TournamentDraftForm` needs from its view model, so creating and editing share one screen.
protocol TournamentDraftEditing: AnyObject, Observable {
    var draft: TournamentDraft { get set }
    var issues: [TournamentDraft.Issue] { get }
    var isSubmitting: Bool { get }
    var canSubmit: Bool { get }
    /// The backend answered; the sheet closes.
    var isDone: Bool { get }
    var earliestStart: Date { get }
    /// The entries the stepper offers; an edit's floor is the entries already in.
    var entriesRange: ClosedRange<Int> { get }
    /// After the start the schedule, the draws and the entries are fixed; only the name, description and place change.
    var isLocked: Bool { get }
    var lockedGroup: EventGroupRef? { get }
    var showsGroupRow: Bool { get }
    var eligibleGroups: [EventGroupRef] { get }
    var explainsNoEligibleGroups: Bool { get }
    func prepare() async
    func submit() async
}

extension TournamentDraftEditing {
    /// The first of `candidates` the draft has, for the hint under the section they concern.
    func issue(for candidates: TournamentDraft.Issue...) -> TournamentDraft.Issue? {
        let present = issues
        return candidates.first { present.contains($0) }
    }

    /// The type, format, team size and visibility are fixed once the tournament exists: an edit never offers them.
    var allowsStructureChanges: Bool { self is CreateTournamentViewModel }
}

extension CreateTournamentViewModel: TournamentDraftEditing {}

extension EditTournamentViewModel: TournamentDraftEditing {}

/// The tournament form in a sheet: Cancel and the submit button in the bar, the fields below. Closes itself once the
/// backend answered.
struct TournamentDraftSheet<Model: TournamentDraftEditing>: View {
    @State private var viewModel: Model
    private let title: String
    private let submitTitle: String
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Tournaments.Create

    init(viewModel: Model, title: String, submitTitle: String, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.submitTitle = submitTitle
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                TournamentDraftForm(viewModel: viewModel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel, role: .cancel) { dismiss() }
                        .disabled(viewModel.isSubmitting)
                        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentFormCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    DraftSubmitButton(title: submitTitle, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                        await viewModel.submit()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentSubmit)
                }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDragIndicator(.visible)
        // Swiping the sheet away mid-request would leave the outcome unknown to the user.
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .task { await viewModel.prepare() }
        .onChange(of: viewModel.isDone) {
            if viewModel.isDone { dismiss() }
        }
    }
}

/// The create form in a sheet: Cancel and Create in the bar. Closes itself once the backend answered.
struct CreateTournamentSheet: View {
    let viewModel: CreateTournamentViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        TournamentDraftSheet(viewModel: viewModel,
                             title: AppBranding.Tournaments.Create.title,
                             submitTitle: AppBranding.Tournaments.Create.submit,
                             errorCenter: errorCenter)
    }
}

/// The organiser's tournament in the form: Cancel and Save in the bar.
struct EditTournamentSheet: View {
    let viewModel: EditTournamentViewModel
    let errorCenter: ErrorCenter

    var body: some View {
        TournamentDraftSheet(viewModel: viewModel,
                             title: AppBranding.Tournaments.Create.editTitle,
                             submitTitle: AppBranding.Tournaments.Create.save,
                             errorCenter: errorCenter)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    CreateTournamentSheet(viewModel: dependencies.makeCreateTournamentViewModel { _ in }, errorCenter: dependencies.errorCenter)
}
