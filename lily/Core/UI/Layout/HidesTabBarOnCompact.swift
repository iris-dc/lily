import SwiftUI

/// Hides the tab bar while the screen is open on a compact width, where a room or the inbox fills the phone, and
/// leaves it to the system on a regular one, where the screen sits in the Chats split view's detail under the tabs'
/// top bar. Judged by `\.layoutMode`, never by the device, so a Split View third of an iPad behaves like a phone.
private struct HidesTabBarOnCompact: ViewModifier {
    @Environment(\.layoutMode) private var layoutMode

    func body(content: Content) -> some View {
        content.toolbarVisibility(layoutMode.isRegular ? .automatic : .hidden, for: .tabBar)
    }
}

extension View {
    /// Goes on a screen that fills a phone but shares an iPad window with the tabs' top bar.
    func hidesTabBarOnCompact() -> some View {
        modifier(HidesTabBarOnCompact())
    }
}
