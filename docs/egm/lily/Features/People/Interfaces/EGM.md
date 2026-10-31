# People Interfaces

Source: `lily/Features/People/Interfaces/`

## Overview

The people boundary: `UserRepository` names the two operations the People feature needs, another user's profile as the
caller may see it and the direct conversation with that user. `UserProfileViewModel` depends on this protocol; the
remote and mock types live in [Implementations](../Implementations/EGM.md), the values in [Models](../Models/EGM.md).

## Interface

- `protocol UserRepository` `[lily/Features/People/Interfaces/UserRepository.swift:UserRepository]` (main-actor
  isolated by the target's default):
  - `func profile(userID: String) async throws -> UserProfile`: throws `AppError.userNotFound` for an unknown or
    deleted account (doc comment).
  - `func startConversation(with userID: String) async throws -> SportGroup`: the direct conversation, a two-member
    private group created on the first call and answered as it is on every later one (the backend derives one id per
    pair), so a repeat is safe (doc comment).

## Invariants

- Doc-comment contract only, no executable guards: failures arrive as `AppError`, ready for the popup;
  `startConversation` is idempotent per pair `[lily/Features/People/Interfaces/UserRepository.swift:UserRepository]`.

## Side Effects

- None: a protocol declaration only.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People` exercises both implementations through this protocol).
