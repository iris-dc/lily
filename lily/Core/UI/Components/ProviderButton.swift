import SwiftUI

/// Full-width glass sign-in button for one provider. Glyph and title sit together in the centre of the capsule, as the
/// system Sign in with Apple button does. Label and glyph use the ink color, never the accent.
struct ProviderButton: View {
    let provider: AuthProvider.Kind
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    private var title: String { AppBranding.signInButtonTitle(for: provider.displayName) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                leadingSlot
                Text(title)
            }
        }
        .lilyGlassButton(labelColor: .lilyInk)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        // The spinner is hidden from VoiceOver, so the value is what says a sign-in is running.
        .accessibilityValue(isLoading ? AppBranding.signingInStatus : "")
    }

    /// The glyph, or while loading a spinner in the glyph's frame, so the title does not move.
    @ViewBuilder private var leadingSlot: some View {
        if isLoading {
            // Resets the button's `.large` control size, which would otherwise inflate the spinner past the glyph frame.
            ProgressView()
                .controlSize(.regular)
                .frame(width: DesignTokens.Layout.providerIconSize, height: DesignTokens.Layout.providerIconSize)
                .accessibilityHidden(true)
        } else {
            ProviderGlyph(provider: provider)
        }
    }
}

/// Provider icon: Apple and Email are SF Symbols in ink (the envelope filled, so it weighs the same as the Apple mark);
/// Google is its official multicolor mark (vector asset).
struct ProviderGlyph: View {
    let provider: AuthProvider.Kind

    var body: some View {
        Group {
            switch provider {
            case .apple:
                Image(systemName: DesignTokens.Symbols.apple)
                    .font(.system(size: DesignTokens.Layout.providerIconSize, weight: .medium))
            case .google:
                Image(.googleLogo)
                    .resizable()
                    .scaledToFit()
            case .email:
                Image(systemName: DesignTokens.Symbols.email)
                    .font(.system(size: DesignTokens.Layout.providerIconSize, weight: .regular))
            }
        }
        .frame(width: DesignTokens.Layout.providerIconSize, height: DesignTokens.Layout.providerIconSize)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        VStack(spacing: DesignTokens.Spacing.md) {
            ProviderButton(provider: .apple) {}
            ProviderButton(provider: .google, isLoading: true) {}
            ProviderButton(provider: .email) {}
        }
        .padding()
    }
}
