import SwiftUI

/// The group flow's final step: what members may do, the group form's two toggles in one glass card. The scaffold's
/// bottom bar carries the create button here, gated by the whole-draft rule. The step owns no issues.
struct GroupPermissionsPage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .group(.permissions) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    GroupPermissionToggles(membersCanCreateEvents: $viewModel.draft.membersCanCreateEvents,
                                           membersCanInvite: $viewModel.draft.membersCanInvite)
                }
            }
        }
    }
}
