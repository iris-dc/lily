import SwiftUI

/// The floating "+" on Explore: a menu of the kinds the flags offer, each item opening the creation wizard seeded
/// with its kind (the owner's third design round, 2026-11-11 — the in-wizard kind page is gone, so the menu is
/// back); a single offered kind makes it a plain one-tap button again. It only reports the choice; the screen
/// decides between the wizard and sign-in.
struct CreateButton: View {
    let onCreate: (CreationKind) -> Void

    private let kinds = CreationWizardPolicy.kindsOffered(flags: .current)

    var body: some View {
        Group {
            if kinds.count > 1 {
                Menu {
                    ForEach(kinds, id: \.self) { kind in
                        Button(title(for: kind), systemImage: symbol(for: kind)) { onCreate(kind) }
                    }
                } label: {
                    plus
                }
                .menuStyle(.button)
            } else {
                // The policy's offer is never empty (events always ship); the one kind is whatever it names.
                Button {
                    onCreate(kinds.first ?? .event)
                } label: {
                    plus
                }
            }
        }
        .lilyFloatingActionButton()
        .accessibilityLabel(AppBranding.Events.Create.menu)
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsCreate)
    }

    private var plus: some View {
        Image(systemName: DesignTokens.Symbols.create)
            .font(LilyTheme.Fonts.floatingAction)
    }

    private func title(for kind: CreationKind) -> String {
        switch kind {
        case .event: AppBranding.Events.Create.title
        case .group: AppBranding.Groups.Create.title
        case .tournament: AppBranding.Tournaments.Create.title
        }
    }

    private func symbol(for kind: CreationKind) -> String {
        switch kind {
        case .event: DesignTokens.Symbols.addEvent
        case .group: DesignTokens.Symbols.groups
        case .tournament: DesignTokens.Symbols.tournament
        }
    }
}

#Preview {
    ContentScreen {
        CreateButton { _ in }
    }
}
