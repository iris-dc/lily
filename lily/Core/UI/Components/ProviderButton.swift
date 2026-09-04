import SwiftUI

/// Full-width glass sign-in button for one provider.
struct ProviderButton: View {
    let provider: AuthProvider.Kind
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ProviderGlyph(provider: provider)
                Text("Continue with \(provider.displayName)")
                Spacer(minLength: 0)
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .fullWidthButtonLabel()
            .contentShape(.rect)
        }
        .lilyGlassButton()
        .disabled(isDisabled || isLoading)
        .accessibilityLabel("Continue with \(provider.displayName)")
    }
}

/// Provider icon. Google has no SF Symbol; a placeholder mark stands in until the official asset is added.
struct ProviderGlyph: View {
    let provider: AuthProvider.Kind

    var body: some View {
        Group {
            switch provider {
            case .apple:
                Image(systemName: DesignTokens.Symbols.apple)
            case .google:
                Text("G")
                    .font(.system(size: DesignTokens.Layout.providerTextGlyphSize, weight: .heavy, design: .rounded))
            case .email:
                Image(systemName: DesignTokens.Symbols.email)
            }
        }
        .font(.system(size: DesignTokens.Layout.providerIconSize, weight: .medium))
        .frame(width: DesignTokens.Layout.providerIconSize, height: DesignTokens.Layout.providerIconSize)
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
