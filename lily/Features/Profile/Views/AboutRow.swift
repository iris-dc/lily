import SwiftUI

/// The way to the "About you" editor on Profile: the title, what the user wrote (or a nudge to write something) and a
/// chevron.
struct AboutRow: View {
    let store: ProfileStore
    let action: () -> Void

    var body: some View {
        SettingsLinkRow(title: AppBranding.About.title,
                        subtitle: store.bio ?? AppBranding.About.emptySubtitle,
                        systemImage: DesignTokens.Symbols.about,
                        identifier: AccessibilityIdentifiers.profileAbout,
                        action: action)
    }
}

#Preview {
    ContentScreen {
        AboutRow(store: AppDependencies.makeMock().profile) {}
            .padding(DesignTokens.Layout.screenMargin)
    }
}
