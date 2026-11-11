import SwiftUI

/// The tournament flow's who-may-join step: the public/private choice of a standalone tournament as auto-advancing
/// choice cards with the chosen side's explanation under them; a tournament hosted in a group follows the group's
/// visibility, so a chosen group turns the page into a read-only card that says so. The step owns no issues.
struct TournamentWhoPage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Tournaments.Create
    private static var step: CreationStep { .tournament(.whoMayJoin) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            if viewModel.draft.group == nil {
                choiceCards
                Text(viewModel.draft.visibility == .public ? AppBranding.Groups.publicFooter
                                                           : AppBranding.Groups.privateFooter)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            } else {
                followsGroupCard
                Text(AppBranding.Create.tournamentFollowsGroup)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var choiceCards: some View {
        ForEach(GroupVisibility.allCases, id: \.self) { visibility in
            WizardChoiceCard(title: visibility.displayName,
                             systemImage: visibility.symbolName,
                             isSelected: visibility == viewModel.draft.visibility,
                             identifier: AccessibilityIdentifiers.createVisibility(visibility)) {
                pick(visibility)
            }
        }
    }

    private var followsGroupCard: some View {
        GlassCard {
            LabeledContent(Copy.visibility) {
                Text(viewModel.draft.effectiveVisibility.displayName)
            }
        }
    }

    private func pick(_ visibility: GroupVisibility) {
        viewModel.draft.visibility = visibility
        wizard.advance(from: Self.step)
    }
}
