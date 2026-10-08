import SwiftUI

extension View {
    /// The pointer's highlight over a tappable card, tile, row or pin; nothing on touch alone.
    func lilyHoverable() -> some View {
        hoverEffect(.highlight)
    }
}
