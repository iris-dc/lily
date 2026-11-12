import SwiftUI

/// The tournament flow's place step: the shared place name field in the glass capsule with the geocoder's
/// suggestions in one glass card directly under it, then the pick-on-map row pushing the map picker as the path
/// element `CreationStep.tournamentMap`, with the optional detail line between them. A tournament needs both halves
/// of the place and the name really chosen (round 5), so the step owns all four place issues.
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
        WizardStepScaffold(wizard: wizard, step: Self.step, scrollTarget: scrollTarget, onCancel: onCancel) {
            nameField
            if !suggestions.isEmpty { suggestionCard }
            detailField
            mapRow
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
        // Focus drops the moment the stack moves (a write from a view already leaving the hierarchy is ignored),
        // so a pop-return never re-presents the keyboard over the bottom bar.
        .onChange(of: wizard.path) { focusedField = nil }
    }

    /// While places are offered the reveal centers the detail line — the middle of the place cluster — so the typed
    /// field stays visible above it and the map row and hint sit clear of the bottom bar's capsule below it, instead
    /// of compositing under the Next label with the keyboard up; otherwise the focused field, like every field page.
    private var scrollTarget: AnyHashable? {
        suggestions.isEmpty ? focusedField.map { AnyHashable($0) } : AnyHashable(PlaceDetailField.revealMark)
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
            .id(Field.name)
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

    /// The optional detail line the stored name carries after the address (apartment, floor, entrance).
    private var detailField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            PlaceDetailField(detail: $viewModel.draft.locationDetail,
                             identifier: AccessibilityIdentifiers.tournamentLocationDetail)
                .lilyField()
            OptionalMarker()
        }
    }

    private var mapRow: some View {
        WizardPlaceMapRow(mapStep: .tournamentMap,
                          identifier: AccessibilityIdentifiers.createPickOnMap,
                          placeChosen: viewModel.draft.placeChosen,
                          hasSpot: viewModel.draft.coordinate != nil)
    }
}
