import SwiftUI

/// Asks a signed-in caller to agree to the current terms before they take part. The root presents it while
/// `TermsViewModel.isPresented` holds, and it closes only through an acceptance the backend recorded or through
/// "Sign out", never by a swipe.
struct TermsSheet: View {
    let viewModel: TermsViewModel
    let errorCenter: ErrorCenter

    private typealias Copy = AppBranding.Moderation

    var body: some View {
        ContentScreen {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // The copy scrolls so that accessibility sizes read it whole instead of squeezing it into an ellipsis;
                // the two buttons stay under it, within reach.
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        ScreenTitle(text: Copy.termsTitle)
                        Text(Copy.termsMessage)
                            .foregroundStyle(.secondary)
                        legalLinks
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                acceptButton
                signOutButton
            }
            .padding(DesignTokens.Spacing.xl)
            .readableColumn()
        }
        .lilyFormSheet()
        // Agreeing or signing out are the only ways out; on iPad a tap beside a form sheet must not dismiss it either.
        .interactiveDismissDisabled()
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
    }

    /// The three legal links in a row that wraps at accessibility sizes; the 44pt labels keep the lines apart.
    private var legalLinks: some View {
        FlowLayout(spacing: DesignTokens.Spacing.lg, rowSpacing: 0) {
            legalLink(Copy.termsLink, to: viewModel.termsURL)
            legalLink(Copy.privacyLink, to: viewModel.privacyURL)
            legalLink(Copy.supportLink, to: viewModel.supportURL)
        }
    }

    private func legalLink(_ title: String, to destination: URL) -> some View {
        Link(destination: destination) {
            Text(title)
                .font(.subheadline)
                .tappableLabel()
        }
        .buttonStyle(.borderless)
    }

    /// A spinner stands in for the label while the acceptance is in flight; VoiceOver keeps reading "I agree".
    private var acceptButton: some View {
        Button {
            Task { await viewModel.accept() }
        } label: {
            if viewModel.isAccepting {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Copy.accept)
            } else {
                Text(Copy.accept)
            }
        }
        .lilyProminentButton()
        .disabled(viewModel.isAccepting)
        .accessibilityIdentifier(AccessibilityIdentifiers.termsAccept)
    }

    /// The way out without agreeing: a text action under the capsule, so agreeing stays the primary one.
    private var signOutButton: some View {
        Button {
            Task { await viewModel.signOut() }
        } label: {
            Text(AppBranding.signOutAction)
                .font(LilyTheme.Fonts.button)
                .frame(maxWidth: .infinity)
                .tappableLabel()
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.isAccepting)
        .accessibilityIdentifier(AccessibilityIdentifiers.termsSignOut)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    TermsSheet(viewModel: dependencies.makeTermsViewModel(), errorCenter: dependencies.errorCenter)
}
