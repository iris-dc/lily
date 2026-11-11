import SwiftUI

/// The event flow's when step, one idea: when the game starts. The date picker is floored at the earliest start the
/// rules accept; the step owns the too-soon issue.
struct EventWhenPage<Model: EventDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.when) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            GlassCard {
                DatePicker(Copy.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
            }
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
    }
}
