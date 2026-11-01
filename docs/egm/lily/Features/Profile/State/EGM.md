# Profile State

Source: `lily/Features/Profile/State/`

## Overview

`ProfileStore`, the one source of the caller's backend profile (`GET /api/profile`): the name other players see, loaded
once per signed-in session when Profile opens, replaced by the answer of a rename and cleared with the session. A failed
load is logged, never shown, since the header draws a placeholder and the editor works without the read. The store is
built by the composition root (`lily/App/AppDependencies.swift`) and registered as a `SessionObserver`.

## Interface

- `@Observable final class ProfileStore: SessionObserver` `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`:
  `init(repository: any ProfileRepository, identity: any IdentityProvider, logger: any Logging)`;
  `private(set) var profile: Profile?`, `displayName: String?`, `isDefaultName: Bool`, `isLoading: Bool`;
  `loadIfNeeded() async`, `rename(to:) async throws -> Profile`, `sessionDidEnd()`.

## Invariants

- `loadIfNeeded` clears the store for a guest, reuses a profile loaded for the current user (one debug line), and
  otherwise runs one load per user id through `SingleFlight`, so concurrent callers join one request
  `[lily/Features/Profile/State/ProfileStore.swift:loadIfNeeded]`.
- A load's answer is kept only while the same user is the caller (`IdentityProvider.isStillCaller`) and only if no
  rename landed meanwhile: the rename is the newer name, so the read's answer is dropped with a debug line
  `[lily/Features/Profile/State/ProfileStore.swift:performLoad]`.
- `rename(to:)` throws `AppError.sessionExpired` for a guest; the answer replaces the profile when the caller is still
  the same and is returned either way. A failure that leaves the outcome unknown (`.network`, or the route's fallback
  `.profileUpdateFailed`, what a 5xx without a code maps to) is settled by reading the profile back, since Laurel
  commits before it answers: a read showing the trimmed name is the answer and nothing is thrown; a refusal is never
  read back; a read that fails or shows another name rethrows the failure
  `[lily/Features/Profile/State/ProfileStore.swift:rename]`, `[lily/Features/Profile/State/ProfileStore.swift:renamed]`.
- `isDefaultName` is `profile?.displayName == AppConfig.DisplayName.backendDefault`; `sessionDidEnd` clears the profile
  and the user it was loaded for `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`.

## Side Effects

- Network through `ProfileRepository`: `profile()` on a load and on the read-back after an unknown outcome,
  `updateDisplayName(_:)` on a rename.
- Logging, ids only, never the name: `.auth` info for a loaded profile, an updated name and a rename that landed despite
  a failure; `.auth` warning for a failed load and a read-back that failed; `.auth` debug for a cancelled load and a
  rename that did not land; `.cache` debug for a reused profile, a dropped answer (two lines: `isStillCaller`'s
  "Profile answer for a previous caller dropped" and "Profile answer superseded by a rename; dropped") and the clear on
  sign-out `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/ProfileStoreTests.swift`)
