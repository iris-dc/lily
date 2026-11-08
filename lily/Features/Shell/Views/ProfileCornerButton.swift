import SwiftUI

/// The top-left corner control of every tab root: the caller's initials circle when signed in, the person glyph for a
/// guest or a fresh sign-in whose first profile load has not named the caller yet — the same `AvatarCircle` fallback
/// the profile header draws. The initials come from the profile snapshot, there at first frame with no network; the
/// lazy load-on-profile-open rule is untouched, since the sheet's content runs it. Tapping it presents the profile
/// sheet (`AppNavigation.isProfilePresented`, mounted by `MainTabView`). An iOS 26 toolbar item draws its own glass
/// capsule, so the item hides it and the circle's glass is the one surface — no glass on glass.
struct ProfileCornerButton: ToolbarContent {
    let dependencies: AppDependencies

    /// The signed-in caller's initials, or `nil` when the glyph must stand in (a guest, or no known name yet).
    private var initials: String? {
        guard dependencies.sessionController.state.isSignedIn else { return nil }
        guard let initials = dependencies.profile.displayName?.initials, !initials.isEmpty else { return nil }
        return initials
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dependencies.navigation.isProfilePresented = true
            } label: {
                AvatarCircle(initials: initials ?? "",
                             systemImage: initials == nil ? DesignTokens.Symbols.profile : nil,
                             size: DesignTokens.Layout.profileCornerSize)
            }
            .accessibilityLabel(AppBranding.profileTitle)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileCorner)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
