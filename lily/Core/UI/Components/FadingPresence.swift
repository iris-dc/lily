import SwiftUI

/// `content` while `isShown`, fading in and out on `animation`; the `ZStack` keeps a place for it, so a sibling fading
/// the other way shares the frame and no frame between them is blank.
struct FadingPresence<Content: View>: View {
    let isShown: Bool
    let animation: Animation
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if isShown {
                content()
                    .transition(.opacity)
            }
        }
        .animation(animation, value: isShown)
    }
}
