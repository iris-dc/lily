import Foundation

/// What a transport reports besides a payload; the controller decides what each means for the connection.
nonisolated enum RealtimeTransportError: Error, Hashable, Sendable {
    /// The token was refused at connect: the session is over until the user signs in again.
    case unauthorized
    /// `onSubscribe` refused the channel: a stale epoch, or the caller is no longer a member.
    case subscribeRefused
    /// This transport never connects (no realtime API is wired in); chat catches up over REST.
    case unavailable
    /// The connection dropped; a reconnect with backoff follows.
    case connectionLost
}
