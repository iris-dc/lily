# Realtime Implementations

Source: `lily/Core/Realtime/Implementations/`

## Overview

The concrete endpoint providers and transports behind `../Interfaces/EGM.md`. `AppSyncRealtimeTransport` is the
production client of the AppSync Events WebSocket protocol, driving the raw socket through the `EventsSocket` seam
(`URLSessionEventsSocket` here; a fake in tests), split into the main file (connect, disconnect, teardown, mapping)
and `+Frames.swift` (the reader, the subscribe machinery, the keep-alive watchdog). `MockRealtimeTransport` is an
in-memory bus for the `-mock-events` run and tests, and the two endpoint providers answer a fixed URL or the one the
backend reported through `MeStore`. All classes are main-actor (no isolation attribute under the app's default).

## Interface

- `final class FixedRealtimeEndpointProvider: RealtimeEndpointProvider`: `init(url: URL?)`; `endpoint()` answers the
  stored URL [`lily/Core/Realtime/Implementations/FixedRealtimeEndpointProvider.swift:FixedRealtimeEndpointProvider`].
- `final class RemoteRealtimeEndpointProvider: RealtimeEndpointProvider`: `init(override: URL?, me: MeStore)`;
  `endpoint()` answers `override ?? me.realtimeEndpoint ?? AppConfig.Realtime.productionEndpoint`
  [`lily/Core/Realtime/Implementations/RemoteRealtimeEndpointProvider.swift:RemoteRealtimeEndpointProvider.endpoint()`].
- `final class MockRealtimeTransport: RealtimeTransport`: `init(logger: any Logging)`; `connect(endpoint:)`,
  `subscribe(to:)`, `disconnect()`, and `func post(_ envelope: RealtimeEnvelope, to channel: RealtimeChannel)` for the
  mock repositories to publish what the backend would
  [`lily/Core/Realtime/Implementations/MockRealtimeTransport.swift:MockRealtimeTransport`].
- `final class AppSyncRealtimeTransport: RealtimeTransport`:
  `init(socket:tokenProvider:logger:sleep:random:)` (sleep and random injectable for tests); nested
  `struct Entry { channel, continuation, retries: Backoff, retryTask }` keyed by the client-chosen frame id;
  `connect(endpoint:)`, `subscribe(to:)`, `disconnect()`, and the internals the extension shares (`read(_:)`,
  `sendSubscribe(id:)`, `connectionEnded(with:)`, `startWatchdog()`, `finish(_:throwing:)`,
  `settleConnect(with:)`, `nonisolated static mapConnectFailure(_:)`, `nonisolated static upgradeRequest(endpoints:token:)`)
  [`lily/Core/Realtime/Implementations/AppSyncRealtimeTransport.swift:AppSyncRealtimeTransport`].
- `final class URLSessionEventsSocket: EventsSocket`: one `URLSessionWebSocketTask` at a time over an ephemeral
  session; `open(request:)` resumes the task and reads it into the stream, `send(_:)`, `close()` cancels with
  `.goingAway` [`lily/Core/Realtime/Implementations/URLSessionEventsSocket.swift:URLSessionEventsSocket`].

## Invariants

- `AppSyncRealtimeTransport.connect` reads `tokenProvider.accessToken()` afresh (none: `.unavailable`, no socket
  opened), opens the socket with the documented subprotocol handshake (`AppSyncEndpoints` + `EventsOutgoingFrame.handshakeProtocols`),
  sends `connection_init` and completes on `connection_ack`, bounded by `AppConfig.Realtime.connectTimeout`
  (`.connectionLost` when the ack never comes); a failure maps per `mapConnectFailure`: a handshake refused with 401
  is `.unauthorized`, any other 4xx `.unavailable` (the kill switch: catch-up, no popup), everything else
  `.connectionLost`; `CancellationError` passes through and the socket the attempt opened is closed
  [`AppSyncRealtimeTransport.swift:AppSyncRealtimeTransport.connect(endpoint:)`, `AppSyncRealtimeTransport.swift:AppSyncRealtimeTransport.mapConnectFailure(_:)`].
- Every subscribe sends its frame with a token read afresh; `subscribe_error` maps per the agreed rules:
  `SubscriptionCheckFailed` is retried here along `reconnectBackoffSeconds` up to `subscribeRetryLimit` times
  (`subscribe_success` resets the walk), then `.connectionLost`; a type containing `Unauthorized` ends the stream
  `.subscribeRefused`; any other type (and an `error` frame naming the subscription) ends it `.unavailable`
  [`AppSyncRealtimeTransport+Frames.swift:AppSyncRealtimeTransport.handleSubscribeError(_:)`].
- A `data` frame decodes its `event` with `APIJSONCoding.makeDecoder()` into `RealtimeEnvelope` and yields it to its
  own stream; an undecodable event or an unknown id is dropped with a log line, never ends the stream
  [`AppSyncRealtimeTransport+Frames.swift:AppSyncRealtimeTransport.handleData(_:)`].
- The socket ending fails every stream with `.connectionLost` (the controller reconnects with backoff); the keep-alive
  watchdog does the same when no frame arrived within the ack's `connectionTimeoutMs` (default
  `defaultKeepAliveTimeout`; it wakes once per window, so a silence is noticed within one to two windows, never a hard
  bound); `disconnect()` tears everything down, finishes the streams plainly, closes the socket
  and is idempotent; a consumer cancelling its stream sends `unsubscribe` and keeps the connection
  [`AppSyncRealtimeTransport+Frames.swift:AppSyncRealtimeTransport.connectionEnded(with:)`, `AppSyncRealtimeTransport+Frames.swift:AppSyncRealtimeTransport.startWatchdog()`].
- `URLSessionEventsSocket` turns any send or receive failure on a task whose HTTP response is not 101 into
  `EventsSocketFailure.handshakeRefused(status:)`; everything else passes through
  [`URLSessionEventsSocket.swift:URLSessionEventsSocket.failure(of:fallback:)`].
- `MockRealtimeTransport.connect` never throws and refuses nothing
  [`MockRealtimeTransport.swift:MockRealtimeTransport.connect(endpoint:)`].
- Mock subscriptions are keyed by a `UUID`; a stream's `onTermination` removes its entry on the main actor;
  `disconnect()` empties the map and finishes every open continuation; `post` yields only to subscriptions whose
  `channel ==` the posted channel, and nobody listening is fine
  [`MockRealtimeTransport.swift:MockRealtimeTransport.subscribe(to:)`, `MockRealtimeTransport.swift:MockRealtimeTransport.post(_:to:)`].
- `RemoteRealtimeEndpointProvider` precedence is fixed: the debug `-realtime-endpoint` override, then
  `MeStore.realtimeEndpoint`, then `AppConfig.Realtime.productionEndpoint`
  [`RemoteRealtimeEndpointProvider.swift:RemoteRealtimeEndpointProvider.endpoint()`].

## Side Effects

- `AppSyncRealtimeTransport` drives the socket (open, send, close) and runs one reader task, one watchdog task, one
  connect-deadline task and one retry task per failing subscription, all waits through the injected `sleep`. Logging
  under `.chat`, ids only, never the token: warning for "Realtime upgrade refused (HTTP <status>)", "Realtime connect
  failed", "Realtime endpoint is not usable; catch-up only", "No access token for the realtime socket; catch-up only",
  "No access token for a subscribe; catch-up only", "Subscribe check failed on <path>; retrying in
  <N>s", "Subscribe check kept failing on <path>", "Subscribe refused on <path>", "Subscribe to <path> refused by the
  API (<type>); catch-up only", "Subscribe send failed on <path>", "Realtime broadcast error (<type>)",
  "Realtime error frame (<type>)", "Realtime error on <path> (<type>); catch-up only", "Realtime socket ended",
  "Realtime keep-alive timed out", "Dropped an undecodable
  event on <path>", "Realtime connection ack timed out"; debug for the ack, confirmed subscribes, cancelled connects
  and dropped frames [`AppSyncRealtimeTransport.swift:AppSyncRealtimeTransport`, `AppSyncRealtimeTransport+Frames.swift`].
- `URLSessionEventsSocket` opens a WebSocket over `URLSession(configuration: .ephemeral)`; the one network access in
  this directory [`URLSessionEventsSocket.swift:URLSessionEventsSocket.open(request:)`].
- `MockRealtimeTransport` logs under `.chat` at debug ("Mock realtime connected", "Mock realtime disconnected") and
  spawns one `Task { @MainActor }` per terminated stream to drop its entry
  [`MockRealtimeTransport.swift:MockRealtimeTransport`].
- `RemoteRealtimeEndpointProvider` reads `MeStore.realtimeEndpoint` (external type); no network of its own
  [`RemoteRealtimeEndpointProvider.swift:RemoteRealtimeEndpointProvider.endpoint()`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Realtime`:
  `AppSyncRealtimeTransportTests`, `AppSyncRealtimeTransportSubscribeTests` over `FakeEventsSocket`, and
  `RealtimeCatchUpFallbackTests` for the controller's catch-up fall-back)
