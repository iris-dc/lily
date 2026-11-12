# Location Interfaces

Source: `lily/Core/Location/Interfaces/`

## Overview

Two protocols: `LocationService`, the one-shot access to the user's position that screens and lists depend on, and
`LocationUpdateSource`, the seam between `CoreLocationService` and CoreLocation, so the timeout, permission and first-fix
logic can be tested against a scripted source.

## Interface

- `LocationService` (`lily/Core/Location/Interfaces/LocationService.swift:LocationService`): main-actor protocol;
  `currentLocation() async -> Coordinate?`; `forgetMissingFix()`, with an empty default in the extension (caches implement it).
- `LocationUpdateSource` (`lily/Core/Location/Interfaces/LocationUpdateSource.swift:LocationUpdateSource`): `nonisolated
  protocol`; `updates() -> AsyncThrowingStream<LocationFix, any Error>`.
- The types in these signatures are in [Models](../Models/EGM.md); the conformers in [Implementations](../Implementations/EGM.md).

## Invariants

- `currentLocation()` resolves to `nil` when permission is denied or no fix arrives in time, and never throws to the UI
  (`LocationService.swift:LocationService`, the protocol's stated requirement).
- `forgetMissingFix()` drops a remembered "no fix" so the next call asks again and keeps a known position; it is called
  when permission may just have changed, on the return to the foreground (`LocationService.swift:forgetMissingFix`).
- A `LocationUpdateSource` stream is opened fresh per call and stays open until the consumer stops iterating
  (`LocationUpdateSource.swift:updates`).

## Side Effects

- None in this directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Location`).

### `GeocodingService` (2026-11-05)

- `protocol GeocodingService` `[lily/Core/Location/Interfaces/GeocodingService.swift:GeocodingService]`:
  `func coordinate(for name: String, near bias: Coordinate?) async throws -> Coordinate?` (the spot a typed place
  names), `func placeName(for coordinate: Coordinate) async -> String?` (what the place around the spot is called) and
  `func suggestions(for query: String, near bias: Coordinate?) async -> [PlaceSuggestion]` (places answering to a
  partial query, nearest the bias first since 2026-11-12, distinct by `id`, at most
  `AppConfig.Events.placeSuggestionCount`).
- `bias` (the draft's spot, else the user's position or an edited game's stored spot) favours places around it in a
  region `AppConfig.Events.placeSearchRegionMeters` on a side; it is only a hint, so a typed city name still lands on
  the city.
- "Nothing answers" is `nil` or empty. The forward lookup throws `AppError.network` when the geocoder could not be
  asked (offline, throttled, a server failure) and `CancellationError` for a cancelled caller, so a name never looked
  up is never reported as unknown; `placeName` and `suggestions` answer `nil` or empty on any failure. The callers
  (`PlaceResolver` and the form's suggestion rows) decide what each means. `PlaceSuggestion` is in
  [Models](../Models/EGM.md).
