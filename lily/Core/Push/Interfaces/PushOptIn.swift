import Foundation

/// Where a screen asks for the notification permission at the right moment: after the user committed to a game, so the
/// reminder the permission buys is obviously useful. Asks once; later calls are no-ops.
protocol PushOptIn {
    func offerReminders() async
}
