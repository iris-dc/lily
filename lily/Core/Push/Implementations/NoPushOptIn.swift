import Foundation

/// The opt-in of view models built without a coordinator (previews, tests): never asks.
struct NoPushOptIn: PushOptIn {
    func offerReminders() async {}
}
