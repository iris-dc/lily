# Groups State

Source: `lily/Features/Groups/State/`

## Overview

Three `@Observable final class` stores that hold the signed-in caller's groups-related state for the app's lifetime and
conform to `SessionObserver` (implementing `sessionDidEnd`; the other callbacks keep the protocol's empty defaults).
`MyGroupsStore` is the one source of the caller's groups (`groups(in: .mine)`), seeded from and saved to a per-caller
snapshot file, reloaded under the shared freshness rules, and reordered locally when a room message lands (it is the
`RoomActivityRecorder` the chat layer talks to). `MeStore` holds the `GET /api/me` account and the terms-acceptance
state; `BlockListStore` holds the caller's block list. All three load once per caller through a `SingleFlight` keyed by the
caller and drop an answer whose caller has changed. Protocols: [Interfaces](../Interfaces/EGM.md); value types:
[Models](../Models/EGM.md).

## Interface

- `MyGroupsStore: SessionObserver, RoomActivityRecorder`; `init(repository: any GroupRepository, identity: any
  IdentityProvider, changes: ChangeTracker, errorCenter: ErrorCenter, logger: any Logging, now: @escaping () -> Date =
  { .now }, snapshots: any ListSnapshotStore = NoOpListSnapshotStore())`, which builds a `StoreLoader(noun: "groups",
  category: .groups, ...)` and seeds `groups` from the snapshot
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.init`].
- `MyGroupsStore` state: `private(set) var groups: [SportGroup]` (`didSet` saves the snapshot), `private(set) var
  loadVersion: Int`; computed `changesVersion`, `loadFailed`, `hasLoaded`, `isLoading` (from the loader),
  `communities` (`groups.filter(\.isCommunity)`), `eligibleForEvents` (communities where
  `GroupAccess(group:userID:).canCreateEvents(in:)`); no `rooms` or `conversations` view is defined here
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.communities`].
- `MyGroupsStore` methods: `loadIfStale() async`, `reload() async`, `add(_:)`, `replace(_:)`, `apply(_:)`,
  `remove(id:)`, `noteMessage(_:in:)` (the `RoomActivityRecorder` requirement), `sessionDidEnd()`
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.add`].
- `MeStore: SessionObserver`; `init(repository: any MeRepository, identity: any IdentityProvider, errorCenter:
  ErrorCenter, logger: any Logging)`; state `private(set) var account: Account?`, `private(set) var termsOutdated:
  Bool`; computed `needsTerms`, `realtimeEndpoint: URL?`, `attachmentsEnabled`, `isLoading` (`account?.isOperator` is read
  on the account itself); methods
  `loadIfNeeded() async`, `reload() async`, `acceptTerms() async -> Bool`, `noteTermsRequired()`, `sessionDidEnd()`
  [`lily/Features/Groups/State/MeStore.swift`:`MeStore.acceptTerms`].
- `BlockListStore: SessionObserver`; `init(repository: any ModerationRepository, identity: any IdentityProvider,
  logger: any Logging)`; state `private(set) var blockedUserIDs: Set<String>`; methods `loadIfNeeded() async`,
  `reload() async`, `block(userID:) async throws`, `sessionDidEnd()`
  [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.block`].

## Invariants

- All three are `@Observable final class` with no `nonisolated` mark, so main-actor isolated
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore`].
- `MyGroupsStore.groups` has no default value, so the seeding assignment in `init` does not fire `didSet` and writes
  nothing back; a seeded snapshot is not a load (`loadVersion` stays 0, the loader stays never-loaded)
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.init`].
- Snapshots are keyed per caller: `ListSnapshotKey(list: AppConfig.Lists.mineGroupsSnapshot, userID:)` with
  `mineGroupsSnapshot = "groups-mine"`; `saveSnapshot` is skipped when there is no current user, so a signed-out clear
  writes nothing [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.snapshotKey`]
  [`lily/Config/AppConfig.swift`:`AppConfig.Lists.mineGroupsSnapshot`].
- Freshness: `loadIfStale` reloads after `AppConfig.Lists.staleAfter` (60 s), or sooner when the `ChangeTracker`
  version or the caller changed; after a failure it waits `AppConfig.Lists.retryAfterFailure` (10 s); `reload` always
  fetches; a guest (no current user) clears without a request
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.loadIfStale`]
  [`lily/Config/AppConfig.swift`:`AppConfig.Lists.staleAfter`].
- Loads are single-flight keyed by user id through `StoreLoader` (a same-user call joins the flight; a version that
  moved while the request was out runs the load exactly once more inside it)
  [`lily/Core/Changes/StoreLoader.swift`:`StoreLoader.reload`].
- `MeStore.reload` and `BlockListStore.reload` run `load.run(key: userID)`: a same-user call joins the flight, another
  user's waits it out and loads for them [`lily/Features/Groups/State/MeStore.swift`:`MeStore.reload`;
  `lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.reload`].
- `acceptTerms` drops an acceptance answered after the caller signed out: `account` stays as the sign-out left it; a
  refusal answered after the sign-out is dropped the same way (no error log, no `ErrorCenter` report), both through
  `identity.isStillCaller` with the `.cache` debug lines "Terms acceptance for a previous caller dropped" and "Terms
  acceptance failure for a previous caller dropped" [`lily/Features/Groups/State/MeStore.swift`:`MeStore.acceptTerms`].
- On a load answer `groups` is replaced in the backend's order, except that a held group whose locally noted
  `lastMessageAt` is later keeps that message and its `mineOrder` position; `loadVersion` increments only here
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.applyMine`].
- Local edits keep `SportGroup.mineOrder` through the one private `place(_:in:)` (remove by id, insert where
  `mineOrder` puts it, on a local copy so `groups` is written once), shared by `add`, `applyMine` and `noteMessage`:
  `add` replaces any same-id group and inserts in order; `replace` removes a
  group the caller is no longer in or that is deleted and never inserts an unknown one; `apply` (a `group_updated`
  broadcast) ignores groups not in Mine and keeps the stored membership through `keepingMembership(of:)`; `noteMessage`
  moves a group only when `noting(_:)` answers non-nil (a later message) and records no change
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.replace`].
- `recordChange()` (from `add`, `replace`, `remove`) bumps the shared `ChangeTracker` and immediately acknowledges the
  version on the loader, so the store does not reload for a change it already shows
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.recordChange`].
- `communities` excludes `.direct` conversations and `.tournament` rooms (`isCommunity` is `kind == .group`)
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.communities`].
- `MeStore.loadIfNeeded` fetches only when `account == nil` or the loaded user differs; `needsTerms` is `termsOutdated
  || !account.termsAccepted`; `termsOutdated` is set by `noteTermsRequired()` only and cleared by a successful
  `acceptTerms()`, a load whose account has the terms accepted, or the private `clear()` (the session's end, and a
  load or reload with no signed-in user) [`lily/Features/Groups/State/MeStore.swift`:`MeStore.needsTerms`,
  `MeStore.clear`].
- `MeStore.acceptTerms` reloads first and sends the fresh `account.termsVersion`; it answers `false` silently when the
  account is gone (sign-out meanwhile), on cancellation, or when the caller changed while the acceptance was out
  (answer or refusal), and `false` with an `ErrorCenter` report when the reload failed or the acceptance was refused for
  the current caller [`lily/Features/Groups/State/MeStore.swift`:`MeStore.acceptTerms`].
- `BlockListStore` replaces, never merges: `blockedUserIDs = answer` on every load and block; `loadIfNeeded` skips a
  user it already loaded; a guest clears; load failures are a warning only, never reported
  [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.performLoad`].
- A load or block answer is dropped when `identity.isStillCaller` says the caller changed; cancellation is swallowed
  with a debug log [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.performLoad`]
  [`lily/Features/Groups/State/MeStore.swift`:`MeStore.performLoad`].
- `sessionDidEnd` clears everything: `groups = []` plus `loader.reset()`; `account`, `loadedUserID`, `loadFailure`,
  `termsOutdated`; `blockedUserIDs` and `loadedUserID`
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.clear`]
  [`lily/Features/Groups/State/MeStore.swift`:`MeStore.clear`]
  [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.clear`].

## Side Effects

- Network through the injected repositories: `groups(in: .mine, cursor: nil, near: nil)` on a stale `loadIfStale` or
  `reload`; `me()` on `loadIfNeeded`, `reload` and at the start of `acceptTerms`; `acceptTerms(version:)`; `blocks()`
  on the first `loadIfNeeded` per user and on `reload`; `block(userID:)`
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.fetchMine`]
  [`lily/Features/Groups/State/MeStore.swift`:`MeStore.performLoad`]
  [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.block`].
- Disk: `snapshots.load([SportGroup].self, for:)` in `MyGroupsStore.init`; `snapshots.save(groups, for:)` on every
  `groups` change while signed in (load, add, replace, remove, noteMessage)
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.saveSnapshot`].
- `ChangeTracker.recordChange()` from `add`, `replace` and `remove`
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.recordChange`].
- `ErrorCenter`: `MeStore.acceptTerms` reports a refused acceptance or an unreadable account; `MyGroupsStore` load
  failures are reported by `StoreLoader.loadOnce` [`lily/Features/Groups/State/MeStore.swift`:`MeStore.acceptTerms`]
  [`lily/Core/Changes/StoreLoader.swift`:`StoreLoader.loadOnce`].
- Spawned work: every `SingleFlight.run` starts an unstructured `Task` (not a child of the caller) for the load so a
  cancelled caller does not cancel the request [`lily/Core/Concurrency/SingleFlight.swift`:`SingleFlight.run`].
- Logging, ids and counts only: `.groups` info "Loaded N groups", "Block list loaded: N blocked", "User X blocked",
  "Account loaded; terms accepted: ...", "Terms vN accepted"; `.groups` warning for a failed block-list or account
  load, error for a failed terms acceptance; `.groups` debug "Group X moved by message Y" and the cancellations;
  `.cache` debug for reuse, invalidation and sign-out clears
  [`lily/Features/Groups/State/MyGroupsStore.swift`:`MyGroupsStore.applyMine`]
  [`lily/Features/Groups/State/MeStore.swift`:`MeStore.performLoad`]
  [`lily/Features/Groups/State/BlockListStore.swift`:`BlockListStore.performLoad`].
- No `UserDefaults`, timers, sleeps or `NotificationCenter` use in the directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Groups`, for
  example `MyGroupsStoreTests`, `MyGroupsStoreOrderTests`, `MyGroupsStoreCallerTests`, `MyGroupsStoreSnapshotTests`,
  `MeStoreTests`, `MeStoreTermsTests`, `BlockListStoreTests`).
