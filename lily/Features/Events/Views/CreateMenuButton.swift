import SwiftUI

/// The floating "+" on Explore: a menu with a new game and a new group, or the game alone as one tap while groups are
/// switched off. It only reports the choice; the screen decides between the form and sign-in.
struct CreateMenuButton: View {
    let onCreateGame: () -> Void
    let onCreateGroup: () -> Void

    var body: some View {
        Group {
            if AppConfig.FeatureFlags.groups {
                Menu {
                    Button(AppBranding.Events.Create.title, systemImage: DesignTokens.Symbols.addEvent, action: onCreateGame)
                    Button(AppBranding.Groups.Create.title, systemImage: DesignTokens.Symbols.groups, action: onCreateGroup)
                } label: {
                    plus
                }
                .menuStyle(.button)
            } else {
                Button(action: onCreateGame) { plus }
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
}

#Preview {
    ContentScreen {
        CreateMenuButton(onCreateGame: {}, onCreateGroup: {})
    }
}
