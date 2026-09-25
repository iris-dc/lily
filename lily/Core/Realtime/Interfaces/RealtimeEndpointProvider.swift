import Foundation

/// Where the realtime API lives. `nil` means no realtime for now: chat catches up over REST, and the question is asked
/// again on the next foreground.
protocol RealtimeEndpointProvider {
    func endpoint() async -> URL?
}
