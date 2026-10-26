import SwiftUI

/// The language setting on Profile, for guests and users alike: a card that opens a menu of "System" and every
/// language naming itself. A pick applies at once: `MainTabView` rebuilds each tab's tree under it, animated here, so
/// this screen crossfades into the new language while the menu closes on its own curve, rather than vanishing with the
/// old tree.
struct LanguageRow: View {
    let language: LanguageStore

    var body: some View {
        SettingsMenuRow(title: AppBranding.Settings.language, systemImage: DesignTokens.Symbols.language, value: value) {
            Picker(AppBranding.Settings.language, selection: selection) {
                Text(AppBranding.Settings.systemLanguage).tag(LanguagePreference.system)
                ForEach(AppLanguage.allCases, id: \.self) { choice in
                    Text(verbatim: choice.nativeName).tag(LanguagePreference.fixed(choice))
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.profileLanguage)
    }

    private var value: String {
        switch language.preference {
        case .system: AppBranding.Settings.systemLanguage
        case .fixed(let choice): choice.nativeName
        }
    }

    private var selection: Binding<LanguagePreference> {
        Binding(get: { language.preference },
                set: { choice in withAnimation(.smooth(duration: DesignTokens.Duration.normal)) { language.select(choice) } })
    }
}

#Preview {
    ContentScreen {
        LanguageRow(language: AppDependencies.makeMock().language)
            .padding(DesignTokens.Layout.screenMargin)
    }
}
