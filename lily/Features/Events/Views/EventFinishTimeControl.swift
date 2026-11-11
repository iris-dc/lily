import SwiftUI

/// The optional finish time of a game, shared by the wizard's When page and the edit form: an add affordance while
/// none is set, and the picker with a clear button once one is. The picker is floored at the start, and a start moved
/// past a set finish is the `endsBeforeStart` issue, so the control never silently rewrites either half. The add
/// affordance is a text button in ink with the accent on its plus mark alone: body-size accent text reads at about
/// 3:1 over the aurora.
struct EventFinishTimeControl<Model: EventDraftEditing>: View {
    @Bindable var viewModel: Model

    private typealias Copy = AppBranding.Events.Create

    var body: some View {
        if viewModel.draft.endsAt == nil {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    viewModel.draft.endsAt = viewModel.draft.startsAt
                        .addingTimeInterval(AppConfig.Events.Creation.proposedDuration)
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: DesignTokens.Symbols.create)
                            .foregroundStyle(Color.lilyAccent)
                        Text(Copy.addEndsAt)
                    }
                }
                .lilyTextButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.createEndsAtAdd)
                Spacer()
                OptionalMarker()
            }
        } else {
            HStack(spacing: DesignTokens.Spacing.sm) {
                DatePicker(Copy.endsAt, selection: endsAt, in: viewModel.draft.startsAt...)
                    .accessibilityIdentifier(AccessibilityIdentifiers.createEndsAt)
                Button {
                    viewModel.draft.endsAt = nil
                } label: {
                    Image(systemName: DesignTokens.Symbols.removeFinishTime)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Copy.removeEndsAt)
                .accessibilityIdentifier(AccessibilityIdentifiers.createEndsAtRemove)
            }
        }
    }

    /// The picker's non-optional binding; the fallback is never shown (the picker is gone once the finish is cleared).
    private var endsAt: Binding<Date> {
        Binding(get: { viewModel.draft.endsAt ?? viewModel.draft.startsAt },
                set: { viewModel.draft.endsAt = $0 })
    }
}
