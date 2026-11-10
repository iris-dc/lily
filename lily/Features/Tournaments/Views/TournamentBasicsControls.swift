import SwiftUI

/// The structural basics of a tournament, offered only while structure changes are allowed: the event type and the
/// format, both fixed once the tournament exists.
struct TournamentBasicsControls<Model: TournamentDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Tournaments.Create

    var body: some View {
        typeChips
        formatPicker
    }

    /// Single choice in the filter sheet's chip look; one type is always selected.
    private var typeChips: some View {
        CaptionedControl(Copy.eventType) {
            EventTypeChips(isSelected: { $0 == viewModel.draft.type }, onSelect: { type in
                if let type { viewModel.draft.type = type }
            })
        }
    }

    /// Changing the format pulls the entries back under its cap.
    private var formatPicker: some View {
        CaptionedControl(Copy.format) {
            Picker(Copy.format, selection: formatSelection) {
                ForEach(TournamentFormat.known, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentFormat)
        }
    }

    /// The draft owns the clamp, so the picker writes the format through `select(format:)`.
    private var formatSelection: Binding<TournamentFormat> {
        Binding(get: { viewModel.draft.format }, set: { viewModel.draft.select(format: $0) })
    }
}
