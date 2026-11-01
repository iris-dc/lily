import SwiftUI

/// A settings link as one glass card: an icon, the title, a line on what it is for and a chevron, the whole card the
/// button. Profile's display name and contact rows share it.
struct SettingsLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Label {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(title)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: systemImage)
                    }
                    Spacer()
                    Image(systemName: DesignTokens.Symbols.chevron)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(identifier)
    }
}
