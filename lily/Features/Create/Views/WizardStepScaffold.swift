import SwiftUI

/// The chrome every wizard step shares: the step title as the navigation title with the animated progress mark under
/// it (the plural-safe "Step n of m" stays as the mark's accessibility label), one short caption under every step
/// title (the owner's third design round, 2026-11-11), the page's fields easing in over the aurora with a reader that
/// brings the focused field into view, Cancel in the toolbar, and a transparent bottom bar carrying the one primary
/// button — Next, or the submit button on the final step — its capsule sitting directly over the content and the
/// aurora (the same round's supersession of the opaque-bar pin). On the final step a
/// stale issue an earlier step owns is named in a hint that pops back to that step. Per-step copy and identifiers
/// come from `WizardStepCopy.swift`. The scaffold draws transparent content only: the one aurora lives in the wizard
/// shell (`CreationWizardView`), so a push composites one live aurora and grain instead of two full layers (the
/// third round's performance pass).
struct WizardStepScaffold<Content: View>: View {
    let wizard: any CreationWizardControlling
    let step: CreationStep
    /// The focused field's scroll anchor; the page passes its focus value and marks the field with `.id`.
    var scrollTarget: AnyHashable?
    let onCancel: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    WizardProgressBar(number: number, count: wizard.steps.count)
                    enteringContent
                }
                .padding(DesignTokens.Layout.screenMargin)
                .readableColumn()
            }
            .onChange(of: scrollTarget) { reveal(scrollTarget, in: proxy) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.createStep)
        .safeAreaInset(edge: .bottom) { bottomBar }
        // The navigation hosting paints an opaque page background that would hide the shell's aurora; cleared here,
        // the page is truly transparent and the one aurora shows through every step.
        .containerBackground(Color.clear, for: .navigation)
        .navigationTitle(step.wizardTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { WizardCancelItem(isDisabled: wizard.isSubmitting, action: onCancel) }
    }

    /// The caption and the page's fields ease in together on entry; the progress mark above them stays put and
    /// animates its fill instead.
    private var enteringContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if let caption = step.wizardCaption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .wizardEntrance()
    }

    private var number: Int { (wizard.steps.firstIndex(of: step) ?? 0) + 1 }

    private var isLast: Bool { wizard.steps.last == step }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if isLast, let blocked = wizard.blockedEarlierStep(before: step),
               let message = wizard.blockingMessage(on: blocked) {
                blockedHint(step: blocked, message: message)
            }
            primaryButton
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var primaryButton: some View {
        if isLast {
            DraftSubmitButton(title: step.wizardSubmitTitle,
                              isSubmitting: wizard.isSubmitting,
                              isEnabled: wizard.canSubmit,
                              sizing: .flexible,
                              controlSize: .large) { await wizard.submit() }
                .accessibilityIdentifier(step.wizardSubmitIdentifier)
        } else {
            Button(AppBranding.Create.next) { wizard.advance(from: step) }
                .lilyProminentButton()
                .disabled(!wizard.allowsNext(from: step))
                .accessibilityIdentifier(AccessibilityIdentifiers.createNext)
        }
    }

    /// The earlier step's stale issue in the shared hint look, the step's own name under it; tapping pops back there.
    private func blockedHint(step blocked: CreationStep, message: String) -> some View {
        Button {
            wizard.pop(to: blocked)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                ValidationHint(message)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: DesignTokens.Symbols.back)
                    Text(blocked.wizardTitle)
                }
            }
        }
        .lilyTextButton(font: LilyTheme.Fonts.caption)
    }

    private func reveal(_ target: AnyHashable?, in proxy: ScrollViewProxy) {
        guard let target else { return }
        if motion.allowsMovement {
            withAnimation { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

/// The wizard's Cancel, shared by every step: a plain toolbar text action under the existing identifier, disabled
/// while a submit is in flight (the locked-while-busy contract).
struct WizardCancelItem: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(AppBranding.Forms.cancel, role: .cancel, action: action)
                .lilyToolbarTextButton()
                .disabled(isDisabled)
                .accessibilityIdentifier(AccessibilityIdentifiers.createCancel)
        }
    }
}

/// The first live issue a step owns, under its fields in the shared hint look; nothing when the page is clean.
struct WizardIssueHint: View {
    let message: String?

    var body: some View {
        if let message {
            ValidationHint(message)
                .font(LilyTheme.Fonts.caption)
        }
    }
}
