import SwiftUI

/// The tournament flow's place step: the shared place name field in the glass capsule with the geocoder's
/// suggestions in one glass card directly under it, then the pick-on-map row pushing the map picker as the path
/// element `CreationStep.tournamentMap`. A tournament needs both halves of the place, so the step owns all three
/// place issues.
struct TournamentPlacePage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    /// The geocoder's places for the typed name, filled by `PlaceNameField`'s debounced machinery.
    @State private var suggestions: [PlaceSuggestion] = []
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .tournament(.place) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            nameField
            if !suggestions.isEmpty { suggestionCard }
            mapRow
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    private var nameField: some View {
        PlaceNameField(name: $viewModel.draft.locationName,
                       identifier: AccessibilityIdentifiers.tournamentLocationName,
                       focus: $focusedField,
                       equals: .name,
                       suggestions: $suggestions,
                       query: { viewModel.draft.placeSuggestionQuery },
                       search: { await viewModel.placeSuggestions(for: $0) })
            .lilyField()
    }

    /// Picking a place fills the name and the spot at once and clears the rows; the shared rows keep their
    /// per-position identifiers.
    private var suggestionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                PlaceSuggestionRows(suggestions: suggestions) { suggestion in
                    viewModel.draft.apply(suggestion)
                    suggestions = []
                }
            }
        }
    }

    private var mapRow: some View {
        GlassNavigationRow(value: CreationStep.tournamentMap, identifier: AccessibilityIdentifiers.createPickOnMap) {
            LabeledContent(Copy.pickOnMap) {
                Text(viewModel.draft.coordinate == nil ? Copy.spotNotSet : Copy.spotSet)
            }
        }
    }
}
