# Location Models

Source: `lily/Core/Location/Models/`

## Overview

Framework-free position types, so models and tests never import CoreLocation: `Coordinate` with great-circle distance and
the backend's rounding, `LocationFix` as one update reduced to what the service acts on, the CoreLocation bridge kept in
its own file, the mock-fixture offset, and road-style distance text.

## Interface

- `Coordinate` (`lily/Core/Location/Models/Coordinate.swift:Coordinate`): `nonisolated struct: Codable, Hashable, Sendable`;
  `latitude`, `longitude: Double`; `distance(to:) -> Double` (metres, haversine over an Earth radius of 6,371,000 m);
  `rounded(toDecimals:) -> Coordinate`; `coarse: Coordinate` (rounded to `AppConfig.Events.positionPrecision`).
- `Coordinate` CoreLocation bridge (`lily/Core/Location/Models/Coordinate+CoreLocation.swift`):
  `init(_ coordinate: CLLocationCoordinate2D)`, `clCoordinate: CLLocationCoordinate2D`.
- `Coordinate.aroundMockCenter(lat:lon:) -> Coordinate` (`lily/Core/Location/Models/Coordinate+MockOffset.swift`):
  `AppConfig.Location.mockCenter` plus each fraction times `AppConfig.Location.fixtureSpreadDegrees`.
- `LocationFix` (`lily/Core/Location/Models/LocationFix.swift:LocationFix`): `nonisolated struct: Equatable, Sendable`;
  `coordinate: Coordinate?` (`nil` for updates that only carry status), `isDenied: Bool`.
- `Measurement<UnitLength>.roadText(locale: Locale = AppLocale.locale) -> String`
  (`lily/Core/Location/Models/Measurement+Road.swift`): `.measurement(width: .abbreviated, usage: .road)`.

## Invariants

- `rounded(toDecimals:)` rounds both components halves away from zero (`Double.rounded()`), as the backend rounds them;
  `coarse` is what Explore sends with a request and what its staleness check compares, so the two cannot drift apart
  (`Coordinate.swift:rounded(toDecimals:)`, `coarse`).
- `distance(to:)` clamps the haversine term with `min(1, sqrt(a))` before `asin` (`Coordinate.swift:distance(to:)`).
- `roadText` reads its default locale per call, so it follows a language or Region change (`Measurement+Road.swift:roadText`).

## Side Effects

- None; `roadText` reads `AppLocale.locale` (`lily/Core/Localization/AppLocale.swift`).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Location`).
