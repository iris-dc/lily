import SwiftUI

/// The language setting on Profile, for guests and users alike: a card that opens a menu of "System" and every
/// language naming itself. A pick applies at once; `AppRootView` rebuilds the tree under it.
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
        Binding(get: { language.preference }, set: { language.select($0) })
    }
}

#Preview {
    ContentScreen {
        LanguageRow(language: AppDependencies.makeMock().language)
            .padding(DesignTokens.Layout.screenMargin)
    }
}
