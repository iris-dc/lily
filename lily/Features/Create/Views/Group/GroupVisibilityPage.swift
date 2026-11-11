import SwiftUI

/// The group flow's visibility step, one idea: who can join, fixed once created. Auto-advancing choice cards with
/// the chosen side's explanation under them; the caption carries the public-place rule the Place page then applies.
/// The step owns no issues: one side is always chosen.
struct GroupVisibilityPage<Model: GroupDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private static var step: CreationStep { .group(.visibility) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            ForEach(GroupVisibility.allCases, id: \.self) { visibility in
                WizardChoiceCard(title: visibility.displayName,
                                 systemImage: visibility.symbolName,
                                 isSelected: visibility == viewModel.draft.visibility,
                                 identifier: AccessibilityIdentifiers.createVisibility(visibility)) {
                    pick(visibility)
                }
            }
            Text(viewModel.draft.visibility == .public ? AppBranding.Groups.publicFooter
                                                       : AppBranding.Groups.privateFooter)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func pick(_ visibility: GroupVisibility) {
        viewModel.draft.visibility = visibility
        wizard.advance(from: Self.step)
    }
}
