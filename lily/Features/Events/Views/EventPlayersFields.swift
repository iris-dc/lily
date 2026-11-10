import SwiftUI

/// Whether the game takes any number, up to a cap or at least a number it needs, and that number when there is one;
/// the stepper's label repeats which of the two it is. The section header and the first-issue footer stay with the form.
struct EventPlayersFields<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        Picker(Copy.playersSection, selection: $viewModel.draft.playerLimit) {
            ForEach(PlayerLimit.allCases, id: \.self) { limit in
                Text(Copy.name(for: limit)).tag(limit)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.createPlayerLimit)
        if viewModel.draft.playerLimit.hasCapacity {
            Stepper(value: $viewModel.draft.capacity, in: viewModel.capacityRange) {
                Text(Copy.capacity(viewModel.draft.capacity, needed: viewModel.draft.allowsExtraParticipants))
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.createCapacity)
        }
    }
}
