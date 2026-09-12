import SwiftUI

/// The floating "+" on Explore. It only reports the tap; the screen decides between the create sheet and sign-in.
struct CreateEventButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DesignTokens.Symbols.create)
                .font(LilyTheme.Fonts.floatingAction)
        }
        .lilyFloatingActionButton()
        .accessibilityLabel(AppBranding.Events.Create.button)
        .accessibilityIdentifier(AccessibilityIdentifiers.eventsCreate)
    }
}

#Preview {
    ContentScreen {
        CreateEventButton {}
    }
}
