import SwiftUI

/// The group flow's place step: the shared place name field in the glass capsule with the geocoder's suggestions in
/// one glass card directly under it, the optional detail line (apartment, floor, entrance) that joins the stored
/// name, then the pick-on-map row pushing the map picker as the path element `CreationStep.groupMap`. The place issues stay conditional on the visibility choice exactly as `GroupDraft`
/// computes them — a private group may leave the place out, a public one is found by it (the step's caption and
/// the Visibility page's both state the rule).
struct GroupPlacePage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void
    /// The geocoder's places for the typed name, filled by `PlaceNameField`'s debounced machinery.
    @State private var suggestions: [PlaceSuggestion] = []
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name }

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .group(.place) }

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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            PlaceNameField(name: $viewModel.draft.locationName,
                           identifier: AccessibilityIdentifiers.createGroupLocationName,
                           focus: $focusedField,
                           equals: .name,
                           suggestions: $suggestions,
                           query: { viewModel.draft.placeSuggestionQuery },
                           search: { await viewModel.placeSuggestions(for: $0) })
                .lilyField()
                .id(Field.name)
            if viewModel.draft.visibility == .private {
                OptionalMarker()
            }
        }
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
                             identifier: AccessibilityIdentifiers.createGroupLocationDetail)
                .lilyField()
            OptionalMarker()
        }
    }

    private var mapRow: some View {
        WizardPlaceMapRow(mapStep: .groupMap,
                          identifier: AccessibilityIdentifiers.createGroupPickOnMap,
                          placeChosen: viewModel.draft.placeChosen,
                          hasSpot: viewModel.draft.coordinate != nil)
    }
}
