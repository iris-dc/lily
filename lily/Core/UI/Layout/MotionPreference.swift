import SwiftUI

/// Whether the app may move what the user is not moving themselves: `full` animates, `reduced` (the system's Reduce
/// Motion) fades or cuts instead. Resolved once from `accessibilityReduceMotion` by the root's `motionProvider()` and
/// read as `\.motion`, so every animation site judges the one preference the same way; a drag that follows the finger
/// is the user's own motion and is not judged here.
nonisolated enum MotionPreference: Equatable, Sendable {
    case full
    case reduced

    static func resolve(reduceMotion: Bool) -> MotionPreference {
        reduceMotion ? .reduced : .full
    }

    /// Whether something may travel, grow or spring on its own; a fade in place is allowed either way.
    var allowsMovement: Bool { self == .full }
}

extension EnvironmentValues {
    @Entry var motion: MotionPreference = .full
}

/// Reads the system's Reduce Motion once and publishes the resulting `MotionPreference` to every descendant.
private struct MotionProvider: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(\.motion, MotionPreference.resolve(reduceMotion: reduceMotion))
    }
}

extension View {
    /// Goes on the root view once, outside its sheets, so they read `\.motion` too.
    func motionProvider() -> some View {
        modifier(MotionProvider())
    }
}
