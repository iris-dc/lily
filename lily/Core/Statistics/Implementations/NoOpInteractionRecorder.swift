import Foundation

/// For mock runs, previews and UI tests: nothing is kept, nothing is sent.
final class NoOpInteractionRecorder: InteractionRecorder {
    func record(_ interaction: Interaction) {}

    func flush() async {}
}
