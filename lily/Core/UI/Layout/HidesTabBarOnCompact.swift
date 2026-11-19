import SwiftUI

/// Hides the tab bar while the screen is open on a compact width, where a room or the inbox fills the phone, and
/// leaves it to the system on a regular one, where the screen sits in the Chats split view's detail under the tabs'
/// top bar. Judged by `\.layoutMode`, never by the device, so a Split View third of an iPad behaves like a phone. On a
/// stack whose root `animatesTabBar(depth:)`, the screen only registers its depth there and the root slides the bar
/// away and back. Only a pop frees the registration, never `onDisappear` — a tab switch and a cover both fire that
/// with the screen still in its flow: a path-pushed screen is pruned by the shrinking path, and an item-pushed one
/// registers under its presenter's token (`\.tabBarHideToken`), released when the item binding clears. Elsewhere the
/// screen sets the visibility itself and the bar pops.
private struct HidesTabBarOnCompact: ViewModifier {
    @Environment(\.layoutMode) private var layoutMode
    @Environment(\.tabBarHiding) private var hiding
    @Environment(\.navigationDepth) private var depth
    @Environment(\.tabBarHideToken) private var presenterToken
    @State private var ownToken = UUID()

    func body(content: Content) -> some View {
        if let hiding {
            content.onAppear { hiding.hide(presenterToken ?? AnyHashable(ownToken), at: depth) }
        } else {
            content.toolbarVisibility(layoutMode.isRegular ? .automatic : .hidden, for: .tabBar)
        }
    }
}

extension View {
    /// Goes on a screen that fills a phone but shares an iPad window with the tabs' top bar.
    func hidesTabBarOnCompact() -> some View {
        modifier(HidesTabBarOnCompact())
    }
}
