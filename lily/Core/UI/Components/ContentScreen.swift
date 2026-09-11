import SwiftUI

/// Scaffold for every content screen: the aurora at content strength, with the screen's own content on top.
/// One place to change the layering or intensity of lists, details, the profile and the sign-in forms.
struct ContentScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AuroraBackground(intensity: DesignTokens.Aurora.contentIntensity)
            content()
        }
    }
}
