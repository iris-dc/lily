import SwiftUI

/// The chrome every wizard step shares: the step title as the navigation title with the animated progress mark under
/// it (the plural-safe "Step n of m" stays as the mark's accessibility label), one short caption on the steps whose
/// purpose needs extra knowledge, the page's fields easing in over the aurora with a reader that brings the focused
/// field into view, Cancel in the toolbar, and a bottom bar on an opaque background carrying the one primary button —
/// Next, or the submit button on the final step — so the keyboard never overlaps bare content. On the final step a
/// stale issue an earlier step owns is named in a hint that pops back to that step.
struct WizardStepScaffold<Model: EventDraftEditing, Content: View>: View {
    let wizard: CreationWizardModel<Model>
    let step: CreationStep
    /// The focused field's scroll anchor; the page passes its focus value and marks the field with `.id`.
    var scrollTarget: AnyHashable?
    let onCancel: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.motion) private var motion

    private typealias Copy = AppBranding.Create

    var body: some View {
        ContentScreen {
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.createStep)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(title(for: step))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { WizardCancelItem(isDisabled: wizard.isSubmitting, action: onCancel) }
    }

    /// The caption and the page's fields ease in together on entry; the progress mark above them stays put and
    /// animates its fill instead.
    private var enteringContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if let caption = caption(for: step) {
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
               let issue = wizard.firstBlockingIssue(on: blocked) {
                blockedHint(step: blocked, issue: issue)
            }
            primaryButton
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        // The surface underlay keeps the aurora's brightest patch from bleeding through the bar material.
        .background(.bar)
        .background(Color.lilySurface)
    }

    @ViewBuilder private var primaryButton: some View {
        if isLast {
            DraftSubmitButton(title: submitTitle,
                              isSubmitting: wizard.isSubmitting,
                              isEnabled: wizard.canSubmit,
                              sizing: .flexible,
                              controlSize: .large) { await wizard.submit() }
                .accessibilityIdentifier(AccessibilityIdentifiers.createSubmit)
        } else {
            Button(Copy.next) { wizard.advance(from: step) }
                .lilyProminentButton()
                .disabled(!wizard.allowsNext(from: step))
                .accessibilityIdentifier(AccessibilityIdentifiers.createNext)
        }
    }

    /// The earlier step's stale issue in the shared hint look, the step's own name under it; tapping pops back there.
    private func blockedHint(step blocked: CreationStep, issue: EventDraft.Issue) -> some View {
        Button {
            wizard.pop(to: blocked)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                ValidationHint(AppBranding.Events.Create.message(for: issue))
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: DesignTokens.Symbols.back)
                    Text(title(for: blocked))
                }
            }
        }
        .lilyTextButton(font: LilyTheme.Fonts.caption)
    }

    private var submitTitle: String {
        switch step {
        case .event, .eventMap: AppBranding.Events.Create.submit
        }
    }

    private func title(for step: CreationStep) -> String {
        switch step {
        case .event(.name): Copy.eventName
        case .event(.type): Copy.eventType
        case .event(.when): Copy.eventWhen
        case .event(.group): Copy.eventGroup
        case .event(.place): Copy.eventPlace
        case .event(.players): Copy.eventPlayers
        case .event(.details): Copy.eventDetails
        // Never scaffolded: the map picker draws its own screen; the place title satisfies exhaustiveness.
        case .eventMap: Copy.eventPlace
        }
    }

    /// The one short line under a step title whose purpose needs extra knowledge; the plain steps carry none.
    private func caption(for step: CreationStep) -> String? {
        switch step {
        case .event(.group): Copy.eventGroupCaption
        case .event(.place): Copy.eventPlaceCaption
        case .event(.players): Copy.eventPlayersCaption
        case .event(.details): Copy.eventDetailsCaption
        case .event, .eventMap: nil
        }
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

/// The wizard's Cancel, shared by the kind page and every step: a plain toolbar text action under the existing
/// identifier, disabled while a submit is in flight (the locked-while-busy contract).
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
    let issue: EventDraft.Issue?

    var body: some View {
        if let issue {
            ValidationHint(AppBranding.Events.Create.message(for: issue))
                .font(LilyTheme.Fonts.caption)
        }
    }
}
