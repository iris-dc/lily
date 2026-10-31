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
