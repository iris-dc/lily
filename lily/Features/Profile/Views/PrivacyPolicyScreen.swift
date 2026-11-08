import SwiftUI

/// The privacy policy read in place: pushed from Settings' privacy row (owner correction 2026-11-08 — no browser
/// round trip), the date line, every section of `AppBranding.Privacy` as a heading over its paragraphs, and a footer
/// naming the served page, which stays the canonical address. Like `SettingsScreen`, the language is an input, so the
/// push re-renders in place on a pick instead of popping.
struct PrivacyPolicyScreen: View {
    /// The language the copy is in; a change re-runs this body and every section's text with it.
    let language: AppLanguage

    private typealias Copy = AppBranding.Privacy

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    Text(Copy.updated)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Copy.sections, content: section)
                    Text(Copy.alsoAt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
        }
        // `.contain` first, or the identifier stamps every child and overrides theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.settingsPrivacyPolicy)
        .navigationTitle(AppBranding.Moderation.privacyLink)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ section: Copy.Section) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(section.title)
                .font(LilyTheme.Fonts.cardTitle)
            ForEach(section.paragraphs) { paragraph in
                text(paragraph)
                    .font(.subheadline)
            }
        }
    }

    /// The page's bold lead runs into its paragraph ("Your account. Your email address..."), one wrapping text
    /// (interpolation, since `Text + Text` is deprecated on iOS 26).
    private func text(_ paragraph: Copy.Paragraph) -> Text {
        guard let lead = paragraph.lead else { return Text(paragraph.body) }
        return Text("\(Text(lead).fontWeight(.semibold)) \(paragraph.body)")
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyScreen(language: .english)
    }
}
