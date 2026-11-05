# Profile Implementations

Source: `lily/Features/Profile/Implementations/`

## Overview

The two `ProfileRepository` types: `RemoteProfileRepository` reads and writes the caller's profile on Laurel;
`MockProfileRepository` mirrors Laurel's profile rules in memory, so previews, UI tests and `-mock-events` runs see what
a new account sees without a backend: the default name, no bio, a name or bio stored as Laurel stores it.

## Interface

- `final class RemoteProfileRepository: ProfileRepository`
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:RemoteProfileRepository]`:
  `init(client: any APIClient)`; `profile()`, `updateDisplayName(_:)`, `updateBio(_:)`.
- `final class MockProfileRepository: ProfileRepository`
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:MockProfileRepository]`:
  `init(identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now })`; `profile()`,
  `updateDisplayName(_:)`, `updateBio(_:)`; private `store(_:)`, `normalized(_:)`, `normalizedBio(_:)`.

## Invariants

- The remote read falls back to `AppError.profileUnavailable`, the name write to `AppError.profileUpdateFailed`, the
  bio write to `AppError.aboutUpdateFailed`; all three decode a `Profile` and answer it
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:profile]`,
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:updateDisplayName]`,
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:updateBio]`.
- The mock keeps one profile per user id: the first read creates it with `AppConfig.DisplayName.backendDefault`; a
  rename is stored as Laurel's `normalize` stores it (trimmed, the default for a blank, the first
  `AppConfig.DisplayName.length.upperBound` code points); no word filter, since no mock has one
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:profile]`,
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:normalized]`; a bio is stored as Laurel's
  `normalizeBio` stores it (trimmed, nothing for a blank, the first `AppConfig.About.maxLength` code points), the name
  untouched, and a rename keeps the bio `[lily/Features/Profile/Implementations/MockProfileRepository.swift:updateBio]`,
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:normalizedBio]`.
- All three mock routes throw `AppError.sessionExpired` for a guest
  `[lily/Features/Profile/Implementations/MockProfileRepository.swift:caller]`.
- Both classes are main-actor isolated by the target's default.

## Side Effects

- `GET /api/profile` decoding `Profile`, and `PUT /api/profile` with body `ProfileUpdateRequest { displayName }` or
  `{ bio }` (one field per request) decoding `Profile`
  `[lily/Features/Profile/Implementations/RemoteProfileRepository.swift:RemoteProfileRepository]`,
  `[lily/Config/AppConfig.swift:AppConfig.API.Paths.profile]`.
- Mock: debug logs under `.auth`, "Mock profile created for user <id>" and "Mock profile updated for user <id>" (ids
  only, never the text; one line per write of either field) `[lily/Features/Profile/Implementations/MockProfileRepository.swift:MockProfileRepository]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/RemoteProfileRepositoryTests.swift`,
  `lilyTests/Profile/MockProfileRepositoryTests.swift`)
