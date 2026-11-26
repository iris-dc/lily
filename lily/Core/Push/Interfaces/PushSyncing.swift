import Foundation

/// Where a screen asks the device registration to be brought up to date now: after a mute flipped, so the backend's
/// device row learns before the next sweep rather than on the next launch.
protocol PushSyncing {
    func sync() async
}
