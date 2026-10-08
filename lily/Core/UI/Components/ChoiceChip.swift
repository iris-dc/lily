import SwiftUI

/// Toggle chip for multiple choice inside forms and panels, in the shared selection look (accent glass when on).
/// It draws its own interactive glass so the tint animates while the capsule stays chip-sized; the hit area is a
/// full control height.
struct ChoiceChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(LilyTheme.selectionLabelColor(isSelected: isSelected))
                .lilyChip(LilyTheme.selectionGlass(isSelected: isSelected).interactive())
                .tappableLabel()
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The style is explicit because a `Form` row restyles labels for its icon column, which squeezed chip titles to
    /// nothing and wrapped them one character per line.
    @ViewBuilder private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
        } else {
            Text(title)
        }
    }
}
