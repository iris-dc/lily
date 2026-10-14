import Foundation

/// For mock runs, previews and UI tests: nothing is kept, nothing is sent, so a sign-out has nothing to flush or drop.
final class NoOpInteractionRecorder: InteractionRecorder, SessionObserver {
    func record(_ interaction: Interaction) {}

    func flush() async {}

    func sessionDidEnd() {}
}
