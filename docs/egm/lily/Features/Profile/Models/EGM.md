# Profile Models

Source: `lily/Features/Profile/Models/`

## Overview

The backend's `Profile` and the body of the display-name update, as `nonisolated` `Codable` values with the backend's
key names.

## Interface

- `Profile: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:Profile]`: `userId`,
  `displayName`, `createdAt: Date`.
- `ProfileUpdateRequest: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`:
  `displayName`; the body of `PUT /api/profile`.

## Invariants

- Both types are `nonisolated`, `Sendable`, `let`-only, with synthesized `Codable`
  `[lily/Features/Profile/Models/Profile.swift:Profile]`, `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`.

## Side Effects

- None: value types.

## Verification

- Run: `./scripts/ci.sh unit`
