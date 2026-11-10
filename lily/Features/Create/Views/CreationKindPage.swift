import SwiftUI

/// The wizard's first page when context offers a real choice: one glass choice card per offered kind, reusing the
/// per-kind "New ..." titles, auto-advancing on pick (the model fixes the kind and pushes its first step). Stays the
/// stack root for the whole attempt; the pick is one-way, so it is never navigated back to.
struct CreationKindPage<Model: EventDraftEditing>: View {
    let model: CreationWizardModel<Model>
    let onCancel: () -> Void

    private typealias Copy = AppBranding.Create

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(model.opening.kindsOffered, id: \.self) { kind in
                        choice(for: kind)
                    }
                }
                .padding(DesignTokens.Layout.screenMargin)
                .readableColumn()
            }
        }
        .navigationTitle(Copy.kindTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { WizardCancelItem(isDisabled: model.isSubmitting, action: onCancel) }
    }

    private func choice(for kind: CreationKind) -> some View {
        GlassNavigationRow(title: title(for: kind), systemImage: symbol(for: kind), identifier: identifier(for: kind)) {
            model.enter(kind)
        }
    }

    private func title(for kind: CreationKind) -> String {
        switch kind {
        case .event: Copy.kindEvent
        case .group: Copy.kindGroup
        case .tournament: Copy.kindTournament
        }
    }

    private func symbol(for kind: CreationKind) -> String {
        switch kind {
        case .event: DesignTokens.Symbols.addEvent
        case .group: DesignTokens.Symbols.groups
        case .tournament: DesignTokens.Symbols.tournament
        }
    }

    private func identifier(for kind: CreationKind) -> String {
        switch kind {
        case .event: AccessibilityIdentifiers.createKindEvent
        case .group: AccessibilityIdentifiers.createKindGroup
        case .tournament: AccessibilityIdentifiers.createKindTournament
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        CreationKindPage(model: dependencies.makeCreationWizardModel(seed: .empty) { _ in }, onCancel: {})
    }
}
