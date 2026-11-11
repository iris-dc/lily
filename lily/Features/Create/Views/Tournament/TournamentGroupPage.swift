import SwiftUI

/// The tournament flow's hosting-group step, one idea: where the tournament lives. On the walk exactly when the
/// attempt may choose (the groups flag on, nothing locked by the seed, a group to host in at opening); the
/// eligible-groups read shows as a disabled placeholder until it lands, and No group keeps the tournament its own.
/// The step owns no issues: an optional choice has nothing to refuse.
struct TournamentGroupPage<Model: TournamentDraftEditing>: View {
    let wizard: any CreationWizardControlling
    @Bindable var viewModel: Model
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Events.Create
    private static var step: CreationStep { .tournament(.group) }

    var body: some View {
        WizardStepScaffold(wizard: wizard, step: Self.step, onCancel: onCancel) {
            groupCard
            // Keyed like the row's read-only state, so a groups change since the opening still reads explained.
            if viewModel.hasLoadedGroups && viewModel.eligibleGroups.isEmpty {
                Text(Copy.noEligibleGroups)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The shared group row behind an outer label, since a menu picker outside a `Form` draws no label of its own;
    /// until the groups read lands the row is a bare placeholder, so the choice never flickers into place.
    private var groupCard: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(Copy.group)
                Spacer()
                if viewModel.hasLoadedGroups {
                    HostingGroupRow(lockedGroup: viewModel.lockedGroup,
                                    showsNoEligibleGroups: viewModel.eligibleGroups.isEmpty,
                                    eligibleGroups: viewModel.eligibleGroups,
                                    selection: $viewModel.draft.group)
                        .labelsHidden()
                } else {
                    ProgressView()
                }
            }
        }
    }
}
