import SwiftUI

/// Centered top of a detail screen (event, group, tournament): the subject's mark in a large circle, the title and a
/// caption line under it ("Sat, Nov 29 · 18:00", "Public · 24 members"), so the screen says what it is before
/// anything else.
struct DetailHeader: View {
    let symbolName: String
    var tint: AvatarCircle.Tint = .sport
    let title: String
    var caption: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(systemImage: symbolName, size: DesignTokens.Layout.avatarSize, tint: tint)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(LilyTheme.Fonts.screenTitle)
                    .tracking(DesignTokens.Typography.titleTracking)
                    .multilineTextAlignment(.center)
                if let caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentScreen {
        DetailHeader(symbolName: EventType.football.symbolName,
                     title: "Sunset 5-a-side",
                     caption: "Sat, Nov 29 · 18:00")
    }
}
