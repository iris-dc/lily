import SwiftUI

/// The language setting on Profile, for guests and users alike: a card with the current choice in a menu that offers
/// "System" and every language naming itself. A pick applies at once; `AppRootView` rebuilds the tree under it.
struct LanguageRow: View {
    let language: LanguageStore

    var body: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Label(AppBranding.Settings.language, systemImage: DesignTokens.Symbols.language)
                Spacer()
                Picker(AppBranding.Settings.language, selection: selection) {
                    Text(AppBranding.Settings.systemLanguage).tag(LanguagePreference.system)
                    ForEach(AppLanguage.allCases, id: \.self) { choice in
                        Text(verbatim: choice.nativeName).tag(LanguagePreference.fixed(choice))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier(AccessibilityIdentifiers.profileLanguage)
            }
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
