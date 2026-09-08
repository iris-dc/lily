import SwiftUI

/// Full-width glass sign-in button for one provider. Label and glyph use the ink color, never the accent.
struct ProviderButton: View {
    let provider: AuthProvider.Kind
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    private var title: String { AppBranding.signInButtonTitle(for: provider.displayName) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ProviderGlyph(provider: provider)
                Text(title)
                Spacer(minLength: 0)
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .foregroundStyle(Color.lilyInk)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .fullWidthButtonLabel()
            .contentShape(.rect)
        }
        .lilyGlassButton()
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

/// Provider icon: Apple and Email are SF Symbols in ink; Google is its official multicolor mark (vector asset).
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
