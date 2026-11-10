import SwiftUI

/// A glass choice card for the wizard's single-choice pages: the label, and the accent check on the current choice,
/// so re-entering a decided page shows it. The whole card is the tap target, like `GlassNavigationRow`, but the
/// trailing mark is a selection, not a chevron — the accent goes on the mark, never the words.
struct WizardChoiceCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    if isSelected {
                        Image(systemName: DesignTokens.Symbols.chosen)
                            .font(.subheadline)
                            .foregroundStyle(Color.lilyAccent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
