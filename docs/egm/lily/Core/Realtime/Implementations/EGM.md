# Realtime Implementations

Source: `lily/Core/Realtime/Implementations/`

## Overview

The concrete endpoint providers and transports behind `../Interfaces/EGM.md`. No production socket client lives here:
`NoRealtimeTransport` is the transport of a build without a realtime client, `MockRealtimeTransport` is an in-memory
bus for the `-mock-events` run and tests, and the two endpoint providers answer a fixed URL or the one the backend
reported through `MeStore`. All four classes are main-actor (no isolation attribute under the app's default).

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
- `final class NoRealtimeTransport: RealtimeTransport`: `connect` throws `RealtimeTransportError.unavailable`;
  `subscribe` answers a stream that finishes at once; `disconnect()` is a no-op
  [`lily/Core/Realtime/Implementations/NoRealtimeTransport.swift:NoRealtimeTransport`].

## Invariants

- `MockRealtimeTransport.connect` never throws and refuses nothing
  [`MockRealtimeTransport.swift:MockRealtimeTransport.connect(endpoint:)`].
- Mock subscriptions are keyed by a `UUID`; a stream's `onTermination` removes its entry on the main actor;
  `disconnect()` empties the map and finishes every open continuation; `post` yields only to subscriptions whose
  `channel ==` the posted channel, and nobody listening is fine
  [`MockRealtimeTransport.swift:MockRealtimeTransport.subscribe(to:)`, `MockRealtimeTransport.swift:MockRealtimeTransport.post(_:to:)`].
- `NoRealtimeTransport.connect` always throws `.unavailable`, so a controller over it settles in
  `RealtimeConnectionState.unavailable` and chat catches up over REST
  [`NoRealtimeTransport.swift:NoRealtimeTransport.connect(endpoint:)`].
- `RemoteRealtimeEndpointProvider` precedence is fixed: the debug `-realtime-endpoint` override, then
  `MeStore.realtimeEndpoint`, then `AppConfig.Realtime.productionEndpoint`
  [`RemoteRealtimeEndpointProvider.swift:RemoteRealtimeEndpointProvider.endpoint()`].

## Side Effects

- `MockRealtimeTransport` logs under `.chat` at debug ("Mock realtime connected", "Mock realtime disconnected") and
  spawns one `Task { @MainActor }` per terminated stream to drop its entry
  [`MockRealtimeTransport.swift:MockRealtimeTransport`].
- `RemoteRealtimeEndpointProvider` reads `MeStore.realtimeEndpoint` (external type); no network of its own
  [`RemoteRealtimeEndpointProvider.swift:RemoteRealtimeEndpointProvider.endpoint()`].
- No network, disk or UIKit access in this directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Realtime`)
