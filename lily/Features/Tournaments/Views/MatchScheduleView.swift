import SwiftUI

/// The organiser's time and place for one match, pushed from the match sheet: a date picker, a place name over the
/// tournament's venue (the spot stays the tournament's unless another is picked on the map; an empty name sends the
/// time alone) and Clear while the match has a schedule. Save closes the sheet once the write went through; the
/// detail behind already shows the match with its time. The rules are `MatchScheduleDraft`'s.
struct MatchScheduleView: View {
    let viewModel: TournamentDetailViewModel
    let match: TournamentMatch
    /// Closes the match sheet this screen is pushed in.
    let onDone: () -> Void
    @State private var draft: MatchScheduleDraft

    private typealias Copy = AppBranding.Tournaments.Schedule

    init(viewModel: TournamentDetailViewModel, match: TournamentMatch, now: Date = .now, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.match = match
        self.onDone = onDone
        let proposal = viewModel.tournament.map { MatchSchedule.proposal(for: match, in: $0, now: now) } ?? MatchSchedule()
        _draft = State(initialValue: MatchScheduleDraft(proposal: proposal, now: now))
    }

    var body: some View {
        ContentScreen {
            Form {
                Section(Copy.when) {
                    DatePicker(Copy.time, selection: $draft.scheduledAt, in: draft.earliest...)
                        .accessibilityIdentifier(AccessibilityIdentifiers.matchScheduleTime)
                }
                Section {
                    TextField(Copy.placePlaceholder, text: $draft.locationName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier(AccessibilityIdentifiers.matchLocationName)
                    PlacePickerRow(coordinate: $draft.coordinate)
                } header: {
                    Text(Copy.place)
                } footer: {
                    Text(Copy.placeFooter)
                }
                if hasSchedule {
                    Section {
                        Button(Copy.clear, role: .destructive) { Task { await send(MatchSchedule()) } }
                            .disabled(viewModel.isBusy)
                            .accessibilityIdentifier(AccessibilityIdentifiers.matchScheduleClear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .readableColumn()
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                DraftSubmitButton(title: Copy.save, isSubmitting: viewModel.isBusy, isEnabled: draft.isValid) {
                    await send(draft.schedule(venue: viewModel.tournament?.location.coordinate))
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.matchScheduleSave)
            }
        }
    }

    private var hasSchedule: Bool { match.scheduledAt != nil || match.location != nil }

    private func send(_ schedule: MatchSchedule) async {
        if await viewModel.schedule(match, schedule) { onDone() }
    }
}
