# Realtime Interfaces

Source: `lily/Core/Realtime/Interfaces/`

## Overview

The seams of the realtime layer: where the realtime API lives, the socket to it and, one level down, the raw
WebSocket the AppSync transport drives (`EventsSocket`, so the transport's protocol logic is unit-tested over a
fake). `RealtimeSessionController` (`../EGM.md`) depends on `RealtimeTransport` and `RealtimeEndpointProvider` only;
the concrete types are in `../Implementations/EGM.md`. The protocols carry no isolation attribute, so under the app
target's default `@MainActor` isolation they are main-actor protocols.

## Interface

- `protocol RealtimeEndpointProvider`: `func endpoint() async -> URL?`; `nil` means no realtime for now, chat catches
  up over REST and the question is asked again on the next foreground
  [`lily/Core/Realtime/Interfaces/RealtimeEndpointProvider.swift:RealtimeEndpointProvider`].
- `protocol RealtimeTransport`: `func connect(endpoint: URL) async throws`,
  `func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error>`,
  `func disconnect() async` [`lily/Core/Realtime/Interfaces/RealtimeTransport.swift:RealtimeTransport`].
- `protocol EventsSocket`: `func open(request: URLRequest) -> AsyncThrowingStream<String, any Error>` (the incoming
  text frames), `func send(_ text: String) async throws`, `func close() async` (idempotent, ends the open stream). A
  refused upgrade (the server answered an HTTP status instead of switching protocols) fails the stream or the next
  `send` with `EventsSocketFailure.handshakeRefused(status:)`; a dropped connection fails it with the underlying error
  as is [`lily/Core/Realtime/Interfaces/EventsSocket.swift:EventsSocket`].

## Invariants

The documented contract every `RealtimeTransport` conformer must keep (`lily/Core/Realtime/Interfaces/RealtimeTransport.swift`):

- Nothing flows up the socket: every write is REST; the socket carries only what the backend committed
  [`RealtimeTransport.swift:RealtimeTransport`].
- `connect(endpoint:)` throws `RealtimeTransportError.unauthorized` when the token is refused and `.unavailable` when
  this transport never connects; anything else is a transient failure worth a backoff. It must throw
  `CancellationError` promptly on cancellation; `close()` on the controller cancels a connect in flight
  [`RealtimeTransport.swift:RealtimeTransport.connect(endpoint:)`].
- The token is read from the `AuthTokenProvider` afresh at connect and on every subscribe; a handshake that completes
  after a cancellation is tolerated because the controller disconnects what it opened
  [`RealtimeTransport.swift:RealtimeTransport.connect(endpoint:)`].
- One connection; a subscription stream ends when the channel is refused (`subscribeRefused`), the API refuses it
  outright (`unavailable`: the controller stops and falls to catch-up, never resubscribes), the connection drops
  (`connectionLost`) or the consumer stops reading [`RealtimeTransport.swift:RealtimeTransport.subscribe(to:)`].
- `disconnect()` ends every subscription and the connection, is idempotent, and is safe during an in-flight `connect`
  (it must close what the handshake still opens, or make that connect throw); the controller calls it twice for one
  socket when a close lands mid-handshake [`RealtimeTransport.swift:RealtimeTransport.disconnect()`].

## Side Effects

- None (protocol declarations only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Realtime`)
