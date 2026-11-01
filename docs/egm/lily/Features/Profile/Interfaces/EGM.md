# Profile Interfaces

Source: `lily/Features/Profile/Interfaces/`

## Overview

The profile boundary towards the backend. Identity stays with Cognito, so `ProfileRepository` carries only what the
backend shows to others: the caller's display name, read and written. The implementations are in
[Implementations](../Implementations/EGM.md), the wire types in [Models](../Models/EGM.md), the one caller in
[State](../State/EGM.md).

## Interface

- `protocol ProfileRepository` `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`
  (main-actor isolated by the target's default): `func profile() async throws -> Profile` (`GET /api/profile`) and
  `func updateDisplayName(_ name: String) async throws -> Profile` (`PUT /api/profile`, answering the name as the
  backend stored it: trimmed, cut to its cap).

## Invariants

- The backend creates the profile with its default name on first contact, so a read never finds nothing
  `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`.
- No guards beyond the declarations: two `async throws` requirements.

## Side Effects

- None: a protocol declaration only.

## Verification

- Run: `./scripts/ci.sh unit`
