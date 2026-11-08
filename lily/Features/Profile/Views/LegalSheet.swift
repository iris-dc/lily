import SwiftUI

/// Either legal reading screen presented modally — the sign-up footnote's links; Settings pushes the same screens —
/// in its own stack with Close, so the documents read identically both ways.
struct LegalSheet: View {
    /// Which document, and the mapping back from the footnote's link tokens (`AppConfig.Legal`).
    enum Document: String, Identifiable {
        case terms, privacy

        var id: String { rawValue }

        init?(agreementURL: URL) {
            switch agreementURL {
            case AppConfig.Legal.termsLink: self = .terms
            case AppConfig.Legal.privacyLink: self = .privacy
            default: return nil
            }
        }
    }

    let document: Document
    let language: AppLanguage
    /// Mounted so an error raised while this sheet covers the sign-in flow still draws on the topmost surface.
    let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { closeButton }
                }
        }
        .errorPopup(errorCenter)
    }

    @ViewBuilder
    private var content: some View {
        switch document {
        case .terms: TermsScreen(language: language)
        case .privacy: PrivacyPolicyScreen(language: language)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: DesignTokens.Symbols.dismiss)
        }
        .accessibilityLabel(AppBranding.Forms.close)
        .accessibilityIdentifier(AccessibilityIdentifiers.legalClose)
    }
}

#Preview {
    LegalSheet(document: .terms, language: .english, errorCenter: AppDependencies.makeMock().errorCenter)
}
