# Location

Source: `lily/Core/Location/`

## Overview

One-shot access to the user's position, split into the protocol screens depend on (`Interfaces/`), framework-free
coordinate types (`Models/`), and the CoreLocation, cached and mock services (`Implementations/`). No source files live
directly in this directory.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `LocationService` (one `currentLocation() async -> Coordinate?`
  that never throws, plus `forgetMissingFix()`) and `LocationUpdateSource` (the stream seam over CoreLocation).
- Models: [./Models/EGM.md](./Models/EGM.md) - `Coordinate` (haversine distance, the backend's `coarse` rounding),
  `LocationFix`, the CoreLocation bridge, the mock-fixture offset and road-style distance text.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `CoreLocationService` (first fix or timeout in
  one structured race), `CachedLocationService` (one shared upstream request, a TTL per outcome),
  `CoreLocationUpdateSource` (`CLLocationUpdate.liveUpdates()`), `MockLocationService`.
