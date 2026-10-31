import UIKit

/// UIKit's animations are off from the process start until the shell's first frame has committed. An iOS 26 tab bar
/// places its selection pill on the first tab and slides it to the selected one over its first frames, whatever the
/// selection was when it was built, so a guest's cold launch showed the pill travelling from Home to Explore; a bar laid
/// out while animations are off draws the pill on the selected tab from its first frame. `AppConfig.Launch.animationsResumeFallback`
/// bounds the freeze should the root never appear: an app without UIKit animations would be a worse fault than the slide.
enum LaunchAnimations {
    static func freeze() {
        UIView.setAnimationsEnabled(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Launch.animationsResumeFallback) { resume() }
    }

    /// From the root's `onAppear`: the frame being built commits at the end of this turn of the run loop, the next one
    /// turns the animations back on.
    static func resumeAfterFirstFrame() {
        DispatchQueue.main.async { resume() }
    }

    private static func resume() {
        UIView.setAnimationsEnabled(true)
    }
}
