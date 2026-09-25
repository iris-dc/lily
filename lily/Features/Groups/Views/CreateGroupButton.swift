import SwiftUI

/// The floating "+" on the Groups tab. It only reports the tap; the root decides between the create sheet and sign-in.
struct CreateGroupButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DesignTokens.Symbols.create)
                .font(LilyTheme.Fonts.floatingAction)
        }
        .lilyFloatingActionButton()
        .accessibilityLabel(AppBranding.Groups.Create.button)
        .accessibilityIdentifier(AccessibilityIdentifiers.groupsCreate)
    }
}

#Preview {
    ContentScreen {
        CreateGroupButton {}
    }
}
