import SwiftUI

/// The Where section of the event form: the name field with the geocoder's suggestions under it and the map row,
/// composed from the extracted parts (`PlaceNameField`, `PlaceSuggestionRows`), which the creation wizard stacks in
/// its own order. Its own file because the form is at the SwiftLint file limit; the stored state (`suggestions`,
/// `focusedField`) stays in `EventDraftForm.swift`.
extension EventDraftForm {
    private typealias Copy = AppBranding.Events.Create

    var whereSection: some View {
        Section {
            PlaceNameField(name: $viewModel.draft.locationName,
                           identifier: AccessibilityIdentifiers.createLocationName,
                           focus: $focusedField,
                           equals: .locationName,
                           suggestions: $suggestions,
                           query: { viewModel.draft.placeSuggestionQuery },
                           search: { await viewModel.placeSuggestions(for: $0) })
            detailRow
            PlacePickerRow(coordinate: pickedCoordinate, placeChosen: viewModel.draft.placeChosen)
                .accessibilityIdentifier(AccessibilityIdentifiers.createPickOnMap)
            suggestionRows
        } header: {
            Text(Copy.whereSection)
        } footer: {
            Text(viewModel.issue(for: .placeMissing, .placeNotChosen, .locationNameTooLong)
                .map(Copy.message(for:)) ?? Copy.whereHint)
        }
    }

    /// The optional detail line the stored name carries after the address (apartment, floor, entrance).
    var detailRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            PlaceDetailField(detail: $viewModel.draft.locationDetail,
                             identifier: AccessibilityIdentifiers.createLocationDetail)
            OptionalMarker()
        }
    }

    /// A spot from the map picker is the user's choice (`EventDraft.pickSpot`).
    var pickedCoordinate: Binding<Coordinate?> {
        Binding(get: { viewModel.draft.coordinate }, set: { viewModel.draft.pickSpot($0) })
    }

    /// The geocoder's places for the typed name; picking one fills the name and the spot at once, so the map row and
    /// the stored game agree with what was typed.
    var suggestionRows: some View {
        PlaceSuggestionRows(suggestions: suggestions) { suggestion in
            viewModel.draft.apply(suggestion)
            suggestions = []
            focusedField = nil
        }
    }
}
