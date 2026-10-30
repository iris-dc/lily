import SwiftUI

/// Scaffold for every content screen: the aurora at content strength, with the screen's own content on top.
/// One place to change the layering or intensity of lists, details, the profile and the sign-in forms.
///
/// The aurora is laid out at the window's height from the top of the screen, never at the container's: a sheet's
/// content is extended to the screen's bottom while the keyboard pushes the sheet up, and a mesh stretched to that
/// height and back redrew the whole background on every move of the keyboard. On a full screen the two are the same.
struct ContentScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.windowHeight) private var windowHeight

    var body: some View {
        ZStack {
            // The reader is greedy and lays its child out at its top; the aurora grows into the top safe area itself, so
            // that inset is left out of the height it is given.
            GeometryReader { proxy in
                AuroraBackground(intensity: DesignTokens.Aurora.contentIntensity)
                    .frame(height: windowHeight.map { $0 - proxy.safeAreaInsets.top })
            }
            content()
        }
    }
}
