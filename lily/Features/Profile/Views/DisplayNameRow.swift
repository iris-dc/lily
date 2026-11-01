import SwiftUI

/// The way to the display name editor on Profile, for users (a guest has no name to choose): the title, what the name
/// is for and a chevron. While the name is still the backend's default the line nudges to choose one.
struct DisplayNameRow: View {
    let store: ProfileStore
    let action: () -> Void

    var body: some View {
        SettingsLinkRow(title: AppBranding.DisplayName.title,
                        subtitle: subtitle,
                        systemImage: DesignTokens.Symbols.profile,
                        identifier: AccessibilityIdentifiers.profileName,
                        action: action)
    }

    private var subtitle: String {
        store.isDefaultName ? AppBranding.DisplayName.defaultSubtitle : AppBranding.DisplayName.subtitle
    }
}

#Preview {
    ContentScreen {
        DisplayNameRow(store: AppDependencies.makeMock().profile) {}
            .padding(DesignTokens.Layout.screenMargin)
    }
}
