import SwiftUI

/// The event flow's when step, one idea: when the game starts, and optionally when it ends. The start picker is
/// floored at the earliest start the rules accept; the finish is the shared optional control, so the edit form and
/// the wizard agree. The step owns the too-soon and ends-before-start issues.
struct EventWhenPage<Model: EventDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .event(.when) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    DatePicker(Copy.startsAt, selection: $viewModel.draft.startsAt, in: viewModel.earliestStart...)
                    EventFinishTimeControl(viewModel: viewModel)
                }
            }
            WizardIssueHint(message: wizard.blockingMessage(on: Self.step))
        }
    }
}
