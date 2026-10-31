# Profile Implementations

Source: `lily/Features/Profile/Implementations/`

## Overview

The two `ProfileRepository` types: `RemoteProfileRepository` puts the display name to Laurel; `MockProfileRepository`
accepts every name, so previews, UI tests and `-mock-events` runs never need a backend.

## Interface

- `final class RemoteProfileRepository: ProfileRepository`
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:RemoteProfileRepository]`:
  `init(client: any APIClient)`; `syncDisplayName(_:)`.
- `final class MockProfileRepository: ProfileRepository`
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:MockProfileRepository]`:
  `init(logger: any Logging)`; `syncDisplayName(_:)`.

## Invariants

- The remote request decodes a `Profile` and discards it; a failure falls back to `AppError.unknown`
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:syncDisplayName]`.
- The mock never throws `[lily/Features/Profile/Implementations/MockProfileRepository.swift:syncDisplayName]`.
- Both classes are main-actor isolated by the target's default.

## Side Effects

- `PUT /api/profile` with body `ProfileUpdateRequest { displayName }`
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:syncDisplayName]`,
  `[lily/Config/AppConfig.swift:AppConfig.API.Paths.profile]`.
- Mock: a debug log under `.auth`, "Mock profile sync accepted a display name" (the name itself is not logged)
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:syncDisplayName]`.

## Verification

- Run: `./scripts/ci.sh unit`
