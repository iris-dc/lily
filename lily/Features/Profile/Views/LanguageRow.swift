import SwiftUI

/// The language setting on Profile, for guests and users alike: a card that opens a menu of "System" and every
/// language naming itself. A pick applies at once: Profile re-renders in place and `MainTabView` rebuilds the other
/// tabs' trees, inside an animation, so what the new copy moves on this screen slides rather than jumps.
struct LanguageRow: View {
    let language: LanguageStore

    var body: some View {
        SettingsMenuRow(title: AppBranding.Settings.language,
                        systemImage: DesignTokens.Symbols.language,
                        value: value,
                        identifier: AccessibilityIdentifiers.profileLanguage) {
            Picker(AppBranding.Settings.language, selection: selection) {
                Text(AppBranding.Settings.systemLanguage).tag(LanguagePreference.system)
                ForEach(AppLanguage.allCases, id: \.self) { choice in
                    Text(verbatim: choice.nativeName).tag(LanguagePreference.fixed(choice))
                }
            }
        }
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
