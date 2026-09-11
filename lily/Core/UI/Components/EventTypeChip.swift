import SwiftUI

/// Amber badge naming an event's type on cards and the detail screen.
struct EventTypeChip: View {
    let type: EventType

    var body: some View {
        Label(type.displayName, systemImage: type.symbolName)
            .lilyChip(.regular.tint(Color.lilySecondary.opacity(DesignTokens.Opacity.secondaryGlassTint)))
    }
}
