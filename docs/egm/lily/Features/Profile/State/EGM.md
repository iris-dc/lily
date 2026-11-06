# Profile State

Source: `lily/Features/Profile/State/`

## Overview

`ProfileStore`, the one source of the caller's backend profile (`GET /api/profile`): the name other players see and the
bio, loaded once per signed-in session when Profile opens, replaced by the answer of a rename or a bio write and cleared
with the session. The
last profile shown is kept in the `ListSnapshotStore` and is the first frame of the next launch, a hint the load still
runs over. A failed load is logged, never shown, since the header draws a placeholder and the editors work without the
read. The store is built by the composition root (`lily/App/AppDependencies.swift`) and registered as a
`SessionObserver`.

## Interface

- `@Observable final class ProfileStore: SessionObserver` `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`:
  `init(repository: any ProfileRepository, identity: any IdentityProvider, snapshots: any ListSnapshotStore, logger: any Logging)`;
  `private(set) var profile: Profile?`, `displayName: String?`, `bio: String?`, `isDefaultName: Bool`, `isLoading: Bool`;
  `loadIfNeeded() async`, `rename(to:) async throws -> Profile`, `updateBio(to:) async throws -> Profile`,
  `sessionDidEnd()`; private `Write` (a write's log words), `write(_:landed:send:)`, `settled(_:despite:landed:)`,
  `keep(_:for:)`.

## Invariants

- `init` starts from the snapshot of the current user, if any (`ListSnapshotKey(list: AppConfig.Lists.profileSnapshot,
  userID:)`), with `loadedUserID` nil, so the snapshot shows but never counts as loaded
  `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore.init]`.
- `loadIfNeeded` clears the store for a guest, reuses a profile loaded for the current user (one debug line), otherwise
  reads the user's snapshot when nothing shows yet and runs one load per user id through `SingleFlight`, so concurrent
  callers join one request `[lily/Features/Profile/State/ProfileStore.swift:loadIfNeeded]`.
- A load's answer and a write's both go through `keep(_:for:)`: the profile, `loadedUserID` and the snapshot
  `[lily/Features/Profile/State/ProfileStore.swift:keep]`.
- A load's answer is kept only while the same user is the caller (`IdentityProvider.isStillCaller`) and only if no
  write landed meanwhile: the write is the newer state, so the read's answer is dropped with a debug line
  `[lily/Features/Profile/State/ProfileStore.swift:performLoad]`.
- `rename(to:)` and `updateBio(to:)` are the two writes, both through `write(_:landed:send:)`: `AppError.sessionExpired`
  for a guest; the answer replaces the profile when the caller is still the same and is returned either way. A failure
  that leaves the outcome unknown (`.network`, or the route's fallback, `.profileUpdateFailed` or `.aboutUpdateFailed`,
  what a 5xx without a code maps to) is settled by reading the profile back, since Laurel commits before it answers: a
  read the write's `landed` closure accepts (the trimmed name; the bio as `text.nonBlankTrimmed`, so a clear reads back
  as no bio) is the answer and nothing is thrown; a refusal is never read back; a read that fails or shows another
  value rethrows the failure `[lily/Features/Profile/State/ProfileStore.swift:rename]`,
  `[lily/Features/Profile/State/ProfileStore.swift:updateBio]`, `[lily/Features/Profile/State/ProfileStore.swift:write]`,
  `[lily/Features/Profile/State/ProfileStore.swift:settled]`.
- `isDefaultName` is `profile?.displayName == AppConfig.DisplayName.backendDefault`; `sessionDidEnd` clears the profile
  and the user it was loaded for `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`.

## Side Effects

- Network through `ProfileRepository`: `profile()` on a load and on the read-back after an unknown outcome,
  `updateDisplayName(_:)` on a rename, `updateBio(_:)` on a bio write.
- `ListSnapshotStore.load` at init and at a load for a user whose profile is not shown, `save` with every kept profile;
  the sweep on sign-out is the store's own (`sessionDidEnd` clears memory only).
- Logging, ids only, never the text: `.auth` info for a loaded profile, an updated name ("Display name updated for user"),
  an updated bio ("Bio updated for user") and a write that landed despite a failure ("Rename landed despite", "Bio
  update landed despite"); `.auth` warning for a failed load and a read-back that failed; `.auth` debug for a cancelled
  load and a write that did not land; `.cache` debug for a reused profile, a dropped answer (two lines: `isStillCaller`'s
  "Profile answer for a previous caller dropped" and "Profile answer superseded by a write; dropped") and the clear on
  sign-out `[lily/Features/Profile/State/ProfileStore.swift:ProfileStore]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/ProfileStoreTests.swift`, `lilyTests/Profile/ProfileStoreBioTests.swift`)
