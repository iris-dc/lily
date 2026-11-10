import SwiftUI

/// When the tournament runs: the start, and a registration deadline at the start or earlier. All three controls are
/// disabled once the tournament is locked.
struct TournamentScheduleFields<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Tournaments.Create

    /// Whether entries close at the start or earlier; the picker's two segments.
    private enum Deadline: Hashable {
        case atStart, earlier
    }

    var body: some View {
        DatePicker(AppBranding.Tournaments.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
            .disabled(viewModel.isLocked)
        CaptionedControl(Copy.registration) {
            Picker(Copy.registration, selection: deadline) {
                Text(Copy.deadlineAtStart).tag(Deadline.atStart)
                Text(Copy.deadlineEarlier).tag(Deadline.earlier)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isLocked)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentDeadline)
        }
        if viewModel.draft.registrationClosesAt != nil {
            DatePicker(Copy.registrationClosesAt, selection: registrationClosesAt, in: ...viewModel.draft.startsAt)
                .disabled(viewModel.isLocked)
        }
    }

    /// Switching the deadline on proposes a day before the start; off clears it.
    private var deadline: Binding<Deadline> {
        Binding {
            viewModel.draft.registrationClosesAt == nil ? .atStart : .earlier
        } set: { choice in
            viewModel.draft.registrationClosesAt = choice == .atStart ? nil : viewModel.proposedDeadline()
        }
    }

    private var registrationClosesAt: Binding<Date> {
        Binding(get: { viewModel.draft.registrationClosesAt ?? viewModel.draft.startsAt },
                set: { viewModel.draft.registrationClosesAt = $0 })
    }
}
