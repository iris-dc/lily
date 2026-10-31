# Profile Interfaces

Source: `lily/Features/Profile/Interfaces/`

## Overview

The profile boundary towards the backend. Identity stays with Cognito, so `ProfileRepository` carries only what the
backend shows to others: the display name on the events the user hosts. The implementations are in
[Implementations](../Implementations/EGM.md), the wire types in [Models](../Models/EGM.md).

## Interface

- `protocol ProfileRepository` `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`
  (main-actor isolated by the target's default): `func syncDisplayName(_ name: String) async throws`, telling the
  backend the name to show on events the user hosts.

## Invariants

- None beyond the declaration: no guards, one `async throws` requirement
  `[lily/Features/Profile/Interfaces/ProfileRepository.swift:ProfileRepository]`.

## Side Effects

- None: a protocol declaration only.

## Verification

- Run: `./scripts/ci.sh unit`
