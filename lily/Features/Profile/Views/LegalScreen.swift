import SwiftUI

/// Shared rendering of the legal reading screens (the privacy policy and the terms of use, each pushed from its
/// Settings row): every section of a data-driven legal document as a heading over its paragraphs, styled as reading
/// content on `ContentScreen` under an inline title.
struct LegalScreen: View {
    let title: String
    /// Carried by the content container, with `.contain` first, so it never stamps the children.
    let identifier: String
    let sections: [AppBranding.Legal.Section]

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    ForEach(sections, content: section)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
        }
        // `.contain` first, or the identifier stamps every child and overrides theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ section: AppBranding.Legal.Section) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(section.title)
                .font(LilyTheme.Fonts.cardTitle)
            ForEach(section.paragraphs) { paragraph in
                text(paragraph)
                    .font(.subheadline)
            }
        }
    }

    /// A paragraph's bold lead runs into its body ("Your account. Your email address..."), one wrapping text
    /// (interpolation, since `Text + Text` is deprecated on iOS 26).
    private func text(_ paragraph: AppBranding.Legal.Paragraph) -> Text {
        guard let lead = paragraph.lead else { return Text(paragraph.body) }
        return Text("\(Text(lead).fontWeight(.semibold)) \(paragraph.body)")
    }
}

#Preview {
    NavigationStack {
        LegalScreen(title: AppBranding.Moderation.privacyLink,
                    identifier: AccessibilityIdentifiers.settingsPrivacyPolicy,
                    sections: AppBranding.Privacy.sections)
    }
}
