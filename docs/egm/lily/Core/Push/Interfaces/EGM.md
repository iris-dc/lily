# Push Interfaces

Source: `lily/Core/Push/Interfaces/`

## Overview

The three seams of push notifications: the backend's device registry, the system's permission and APNs registration,
and the moment a screen may ask for the permission. `PushCoordinator` (`../EGM.md`) implements `PushOptIn` and depends
on the other two; the conformers are in `../Implementations/EGM.md`. All three protocols carry no isolation attribute,
so they are main-actor under the app target's default.

## Interface

- `protocol DeviceRepository`: `func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration`,
  `func unregister(token: String) async throws -> DeviceRemoval`
  [`lily/Core/Push/Interfaces/DeviceRepository.swift:DeviceRepository`].
- `protocol PushOptIn`: `func offerReminders() async` [`lily/Core/Push/Interfaces/PushOptIn.swift:PushOptIn`].
- `protocol PushRegistrar`: `func authorization() async -> PushAuthorization`,
  `func requestAuthorization() async -> Bool` (shows the system prompt; `true` when granted),
  `func deviceToken() async throws -> String` (the APNs token as hex; throws when the system refused or stayed silent)
  [`lily/Core/Push/Interfaces/PushRegistrar.swift:PushRegistrar`].

## Invariants

- Documented contract of `PushOptIn`: the permission is asked once, after the user committed to a game; later calls
  are no-ops [`lily/Core/Push/Interfaces/PushOptIn.swift:PushOptIn.offerReminders()`].
- Documented contract of `PushRegistrar`: a mock run (`-mock-events`) never meets the permission alert, which is why
  the system calls sit behind this seam [`lily/Core/Push/Interfaces/PushRegistrar.swift:PushRegistrar`].

## Side Effects

- None (protocol declarations only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Push`)
