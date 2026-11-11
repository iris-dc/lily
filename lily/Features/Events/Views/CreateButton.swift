import SwiftUI

/// The floating "+" on Explore: one tap that opens the creation wizard, whose kind page asks what to make (the menu
/// it carried until slice 3 of the creation-wizard plan is gone). It only reports the tap; the screen decides
/// between the wizard and sign-in.
struct CreateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DesignTokens.Symbols.create)
                .font(LilyTheme.Fonts.floatingAction)
        }
        .lilyFloatingActionButton()
        .accessibilityLabel(AppBranding.Events.Create.menu)
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsCreate)
    }
}

#Preview {
    ContentScreen {
        CreateButton {}
    }
}
