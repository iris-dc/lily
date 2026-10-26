import SwiftUI

/// The language setting on Profile, for guests and users alike: a card that drops down "System" and every language
/// naming itself. A pick applies at once: Profile re-renders in place and `MainTabView` rebuilds the other tabs' trees,
/// with no animation, since an animated pick slid the cards' new values into their chevrons over ten frames.
struct LanguageRow: View {
    let language: LanguageStore

    var body: some View {
        SettingsChoiceRow(title: AppBranding.Settings.language,
                          systemImage: DesignTokens.Symbols.language,
                          value: value,
                          identifier: AccessibilityIdentifiers.profileLanguage,
                          choices: choices,
                          selection: selection)
    }

    private var choices: [SettingsChoice<LanguagePreference>] {
        [SettingsChoice(value: .system, title: AppBranding.Settings.systemLanguage)]
            + AppLanguage.allCases.map { SettingsChoice(value: .fixed($0), title: $0.nativeName) }
    }

    private var value: String {
        switch language.preference {
        case .system: AppBranding.Settings.systemLanguage
        case .fixed(let choice): choice.nativeName
        }
    }

    private var selection: Binding<LanguagePreference> {
        Binding(get: { language.preference }, set: { language.select($0) })
    }
}

#Preview {
    ContentScreen {
        LanguageRow(language: AppDependencies.makeMock().language)
            .padding(DesignTokens.Layout.screenMargin)
    }
}
