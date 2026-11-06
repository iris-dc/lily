import SwiftUI

/// The Where section of the event form: the name field with the geocoder's suggestions under it and the map row. Its
/// own file because the form is at the SwiftLint file limit; the stored state (`suggestions`, `focusedField`) stays in
/// `EventDraftForm.swift`.
extension EventDraftForm {
    private typealias Copy = AppBranding.Events.Create

    var whereSection: some View {
        Section {
            PlaceFields(name: $viewModel.draft.locationName,
                        coordinate: pickedCoordinate,
                        nameIdentifier: AccessibilityIdentifiers.createLocationName,
                        pickerIdentifier: AccessibilityIdentifiers.createPickOnMap,
                        focus: $focusedField,
                        equals: .locationName)
            suggestionRows
        } header: {
            Text(Copy.whereSection)
        } footer: {
            Text(viewModel.issue(for: .placeMissing, .locationNameTooLong).map(Copy.message(for:)) ?? Copy.whereHint)
        }
    }

    /// A spot from the map picker is the user's choice (`EventDraft.pickSpot`).
    var pickedCoordinate: Binding<Coordinate?> {
        Binding(get: { viewModel.draft.coordinate }, set: { viewModel.draft.pickSpot($0) })
    }

    /// The geocoder's places for the typed name; picking one fills the name and the spot at once, so the map row and
    /// the stored game agree with what was typed.
    var suggestionRows: some View {
        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
            Button {
                viewModel.draft.apply(suggestion)
                suggestions = []
                focusedField = nil
            } label: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    // Semantic styles only: an asset colour (`Color.lilyAccent`, `.lilyInk`) stored in these rows
                    // crashed the list diff (EXC_BAD_ACCESS under ForEachState.item). The glyph keeps the button's
                    // accent tint; the title must not be accent at this size, so it takes the absolute label colour
                    // (`Color.primary`, not `.primary`, which only re-derives from the accent tint).
                    Label {
                        Text(suggestion.title).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: DesignTokens.Symbols.location)
                    }
                    if let subtitle = suggestion.subtitle {
                        Text(subtitle).font(LilyTheme.Fonts.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createPlaceSuggestion(index))
        }
    }
}
