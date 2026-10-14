import SwiftUI

/// Glass chip naming a group's visibility ("Public" or "Private") after its glyph, on cards and the group header.
struct VisibilityChip: View {
    let visibility: GroupVisibility

    var body: some View {
        Label(visibility.displayName, systemImage: visibility.symbolName)
            .lilyChip(.regular)
    }
}
