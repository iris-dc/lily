# Location

Source: `lily/Core/Location/`

## Overview

One-shot access to the user's position and the geocoding behind the event form's place, split into the protocols
screens depend on (`Interfaces/`), framework-free coordinate types (`Models/`), and the CoreLocation/MapKit, cached and
mock services (`Implementations/`). No source files live
directly in this directory.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `LocationService` (one `currentLocation() async -> Coordinate?`
  that never throws, plus `forgetMissingFix()`), `LocationUpdateSource` (the stream seam over CoreLocation) and
  `GeocodingService` (`coordinate(for:near:)`, `placeName(for coordinate:)` and `suggestions(for:near:)`, biased to a
  spot; "nothing answers" is `nil` or empty, a geocoder that could not be asked throws `AppError.network` from the
  forward lookup).
- Models: [./Models/EGM.md](./Models/EGM.md) - `Coordinate` (haversine distance, the backend's `coarse` rounding),
  `LocationFix`, `PlaceSuggestion`, the CoreLocation bridge, the mock-fixture offset and road-style distance text.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `CoreLocationService` (first fix or timeout in
  one structured race), `CachedLocationService` (one shared upstream request, a TTL per outcome),
  `CoreLocationUpdateSource` (`CLLocationUpdate.liveUpdates()`), `MockLocationService`, `CoreLocationGeocoder`
  (MapKit's `MKGeocodingRequest`/`MKReverseGeocodingRequest`; the `CLGeocoder` routes are deprecated on iOS 26; logs
  outcomes only, never the text) and `MockGeocodingService` (a non-blank name lands deterministically in the fixtures'
  neighbourhood through `Coordinate.aroundMockCenter`, every spot is called "Berlin").
