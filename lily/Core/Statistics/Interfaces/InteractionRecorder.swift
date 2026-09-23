import Foundation

/// Collects the signed-in user's interactions and sends them in batches. Recording never fails and never blocks the
/// caller; a failed send is a log line, never a popup.
protocol InteractionRecorder {
    func record(_ interaction: Interaction)
    /// Sends whatever is buffered now (the app is going to the background).
    func flush() async
}
