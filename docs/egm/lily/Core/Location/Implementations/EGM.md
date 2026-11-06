# Location Implementations

Source: `lily/Core/Location/Implementations/`

## Overview

The `LocationService`s and the CoreLocation source. `CoreLocationService` takes one fix from the live update stream or
answers `nil` on denial or timeout; `CachedLocationService` wraps another service so concurrent callers share one
upstream request and a recent result is reused; `CoreLocationUpdateSource` reduces `CLLocationUpdate.liveUpdates()` to
`LocationFix`es; `MockLocationService` answers a fixed position for previews, tests and the simulator.

## Interface

- `CoreLocationService: LocationService` (`lily/Core/Location/Implementations/CoreLocationService.swift:CoreLocationService`):
  `init(logger: any Logging, timeout: Duration = AppConfig.Location.fixTimeout, source: any LocationUpdateSource = CoreLocationUpdateSource())`;
  `currentLocation() async -> Coordinate?`.
- `CachedLocationService: LocationService` (`lily/Core/Location/Implementations/CachedLocationService.swift:CachedLocationService`):
  `init(upstream: any LocationService, logger: any Logging, now: @escaping () -> ContinuousClock.Instant = { .now })`;
  `let upstream`; `currentLocation()`, `forgetMissingFix()`.
- `CoreLocationUpdateSource: LocationUpdateSource` (`lily/Core/Location/Implementations/CoreLocationUpdateSource.swift:CoreLocationUpdateSource`):
  `nonisolated struct`; `updates() -> AsyncThrowingStream<LocationFix, any Error>`.
- `MockLocationService: LocationService` (`lily/Core/Location/Implementations/MockLocationService.swift:MockLocationService`):
  `init(coordinate: Coordinate? = AppConfig.Location.mockCenter)`; `currentLocation()` answers it.

## Invariants

- `CoreLocationService.firstFixBeforeTimeout` races the stream against `Task.sleep(for: timeout)` in one structured
  `withThrowingTaskGroup` and cancels the loser (`defer { group.cancelAll() }`), so cancelling the caller closes the
  stream too. `firstFix` answers `nil` on the first `isDenied` update and the first coordinate otherwise; a stream that
  ended checks cancellation before answering `nil`. `currentLocation()` never throws: a cancellation logs at debug, any
  other error at warning, both answer `nil` (`CoreLocationService.swift:currentLocation`, `firstFixBeforeTimeout`, `firstFix`).
- `CachedLocationService.currentLocation()`: a remembered fix is reused while fresh (`RememberedFix.isFresh`:
  `AppConfig.Location.fixTTL` for a coordinate, the shorter `AppConfig.Location.failedFixTTL` for a missing one); a request
  in flight is joined; otherwise one `Task` calls upstream and its result is remembered. The shared request survives a
  caller's cancellation, bounded by the upstream timeout. `forgetMissingFix()` clears only a remembered `nil`
  (`CachedLocationService.swift:currentLocation`, `forgetMissingFix`, `RememberedFix`).
- `CoreLocationUpdateSource.updates()` forwards every `CLLocationUpdate`, finishes (or finishes throwing) when the live
  stream ends, and cancels its forwarding task on stream termination. `LocationFix.isDenied` is
  `authorizationDenied || authorizationDeniedGlobally || authorizationRestricted` (`CoreLocationUpdateSource.swift`).

## Side Effects

- Location services: iterating `CLLocationUpdate.liveUpdates()` prompts for when-in-use permission
  (`CoreLocationUpdateSource.swift:updates`).
- Spawned tasks: a forwarding task per stream (`CoreLocationUpdateSource`); a two-task group with `Task.sleep` for the
  timeout (`CoreLocationService`); one `Task` per upstream request (`CachedLocationService`).
- Logging: `.location` info for a fix acquired, no fix, permission denied; debug for a cancelled request; warning for any
  other error (`CoreLocationService.swift`). `.cache` debug for hit, miss, joined flight and a forgotten missing fix
  (`CachedLocationService.swift`).
- In-memory state: `CachedLocationService.remembered` and `inFlight`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Location`).

### Geocoders (2026-11-05)

- `CoreLocationGeocoder` `[lily/Core/Location/Implementations/CoreLocationGeocoder.swift:CoreLocationGeocoder]`:
  `init(logger:)`; forward through `MKGeocodingRequest(addressString:)`, reverse through
  `MKReverseGeocodingRequest(location:)`, the first map item's `location.coordinate` / non-blank `name`; the
  `CLGeocoder` routes are deprecated on iOS 26; `suggestions(for:)` through `MKLocalSearch` (addresses and points of
  interest, the first `AppConfig.Events.placeSuggestionCount` items as `PlaceSuggestion`s, subtitles from
  `MKAddress.shortAddress`; 2026-11-06). One request object per call. Logs under `.location` by outcome only,
  never the text: a place name is the user's content.
- `MockGeocodingService` `[lily/Core/Location/Implementations/MockGeocodingService.swift:MockGeocodingService]`: a
  non-blank name lands deterministically in the fixtures' neighbourhood (`Coordinate.aroundMockCenter` seeded by the
  name's scalar sum, so the same name is always the same spot); every spot is named "Berlin"; a blank name answers
  `nil`; `suggestions(for:)` offers the demo cities whose names start with the query (Warsaw, Gdansk, Berlin, ...),
  else the query itself, each on its deterministic spot (2026-11-06). Also the default `geocoder` of `AppDependencies.init` and the two event form view models, so tests and
  previews need no wiring.
