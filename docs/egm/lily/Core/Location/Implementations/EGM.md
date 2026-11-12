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
  `CLGeocoder` routes are deprecated on iOS 26. `suggestions(for:near:)` goes through `MKLocalSearchCompleter`,
  MapKit's type-ahead API (2026-11-12; `MKLocalSearch` on a fragment fuzzy-matched famous names worldwide regardless
  of the region — "Gda" answered Jeddah from Gdansk): one private `PlaceCompletionSession` per ask bridges the
  delegate to async (results or a failure resume it; an `AppConfig.Events.placeSuggestionTimeout` deadline settles
  with whatever has arrived, so a callback that never comes cannot hold the field's task), completions are addresses
  and points of interest only, and completions are resolved to full places through a completion-scoped
  `MKLocalSearch` (subtitles from `MKAddress.shortAddress`) until `AppConfig.Events.placeSuggestionCount` distinct
  ones answer (a duplicate by `PlaceSuggestion.id` pulls the next completion instead of thinning the rows), the
  answer ordered `nearestFirst(to:)` the bias. A cancelled ask bails with `[]` after the completions await and
  between resolves, instead of waiting out the deadline and every resolve. A bias sets the request's (and the
  completer's) `region` to an `MKCoordinateRegion`
  `AppConfig.Events.placeSearchRegionMeters` on a side around it (`region(around:)`); since the region is only a hint,
  the forward lookup takes the first match `PlaceMatchPolicy.isUsable` accepts (a point of interest far from the bias
  is skipped, a city or an address never is; `isUsable(_:near:)`). The forward lookup tells "no
  match" from a failure (`rethrowFailure`, `isFailure`): an `MKError` other than `.placemarkNotFound`, a
  `CLError.network` or a `URLError` logs a `.location` warning with the error's domain and code and throws
  `AppError.network`; a cancelled caller gets `CancellationError`; anything else is "no match", `nil`. One request
  object per call. Logs under `.location` by outcome only, never the text: a place name is the user's content.
- `MockGeocodingService` `[lily/Core/Location/Implementations/MockGeocodingService.swift:MockGeocodingService]`: a
  non-blank name lands deterministically in the fixtures' neighbourhood (`Coordinate.aroundMockCenter` seeded by the
  name's scalar sum, so the same name is always the same spot); every spot is named "Berlin"; a blank name answers
  `nil`; `suggestions(for:near:)` offers the demo cities whose names start with the query (Warsaw, Gdansk, Berlin,
  ...), else the query itself, each on its deterministic spot. It ignores the bias and never throws, so
  `-mock-location` runs work offline. Also the default `geocoder` of `AppDependencies.init` and the two event form
  view models, so tests and previews need no wiring. Tests: `lilyTests/Location/PlaceSuggestionTests.swift`.
