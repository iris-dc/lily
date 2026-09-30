import SwiftUI

/// What a sheet over `EventDraftForm` needs from its view model, so creating and editing a game share one screen.
protocol EventDraftEditing: AnyObject, Observable {
    var draft: EventDraft { get set }
    var issues: [EventDraft.Issue] { get }
    var isSubmitting: Bool { get }
    var canSubmit: Bool { get }
    /// The backend answered; the sheet closes.
    var isDone: Bool { get }
    /// The earliest start the date picker offers.
    var earliestStart: Date { get }
    /// The capacities the stepper offers; an edit's floor is the people already in.
    var capacityRange: ClosedRange<Int> { get }
    /// The group the game is hosted in when the form may not change it, shown read-only.
    var lockedGroup: EventGroupRef? { get }
    var showsGroupRow: Bool { get }
    var eligibleGroups: [EventGroupRef] { get }
    var explainsNoEligibleGroups: Bool { get }
    /// Runs once when the sheet appears, before the user types.
    func prepare() async
    func submit() async
}

extension EventDraftEditing {
    /// The first of `candidates` the draft has, for the hint under the section they concern.
    func issue(for candidates: EventDraft.Issue...) -> EventDraft.Issue? {
        let present = issues
        return candidates.first { present.contains($0) }
    }
}

extension CreateEventViewModel: EventDraftEditing {}

extension EditEventViewModel: EventDraftEditing {}

/// The event form in a sheet: Cancel and the submit button in the bar, the fields below. Closes itself once the
/// backend answered.
struct EventDraftSheet<Model: EventDraftEditing>: View {
    @State private var viewModel: Model
    private let title: String
    private let submitTitle: String
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Events.Create

    init(viewModel: Model, title: String, submitTitle: String, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.submitTitle = submitTitle
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                EventDraftForm(viewModel: viewModel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // The semantic placements get the native sheet treatment (a `.borderless` Cancel became an icon-sized
            // circle, "Ca…"). The submit button keeps the toolbar's own glass and size: hiding that glass left the
            // disabled prominent capsule as black text on nothing.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel, role: .cancel) { dismiss() }
                        .disabled(viewModel.isSubmitting)
                        .accessibilityIdentifier(AccessibilityIdentifiers.createCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    DraftSubmitButton(title: submitTitle, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                        await viewModel.submit()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.createSubmit)
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
