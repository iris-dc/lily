import SwiftUI

/// The first few people of a list as overlapping initials circles, "who's there" at a glance; the count beside it
/// says how many they stand for. Draws at most `peopleStackCount` circles, each separated from the one it overlaps
/// by a thin dark rim.
struct AvatarStack: View {
    let names: [String]
    var size: CGFloat = DesignTokens.Layout.avatarSmall

    private var shown: [(offset: Int, element: String)] {
        Array(names.prefix(DesignTokens.Layout.peopleStackCount).enumerated())
    }

    var body: some View {
        HStack(spacing: -size * DesignTokens.Layout.avatarStackOverlap) {
            ForEach(shown, id: \.offset) { entry in
                AvatarCircle(initials: entry.element.initials, size: size)
                    .background {
                        Circle()
                            .fill(Color.black.opacity(DesignTokens.Opacity.avatarStackRim))
                            .padding(-DesignTokens.Layout.avatarStackRimWidth)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentScreen {
        AvatarStack(names: ["Anna Kowalska", "Piotr Nowak", "Jan Wiśniewski", "Marta Lewandowska"])
    }
}
