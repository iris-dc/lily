import SwiftUI

/// The subtle tag on an optional field: one localized word in the caption font and secondary ink, never accent, so
/// nobody wonders what they must fill in. Sits below the control it marks — one placement, never inside or beside
/// it — in the creation wizard's pages and the edit forms alike.
struct OptionalMarker: View {
    var body: some View {
        Text(AppBranding.Forms.optional)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentScreen {
        OptionalMarker()
    }
}
