# Changes

Source: `lily/Core/Changes/`

## Overview

The rules every cached backend answer follows: when content can be reused and when it must be fetched again
(`ContentFreshness`), the app-wide change counters a list compares itself against (`ChangeTracker`), what a list screen
shows for a given state (`ListState`), and the load bookkeeping the app-lifetime stores share (`StoreLoader`: freshness,
one request at a time through `SingleFlight`, answers for a departed caller dropped, failures reported). The snapshot
layer that keeps a list's last answer on the device is in `Interfaces/` and `Implementations/`.

## Interface

- `ContentFreshness` (`lily/Core/Changes/ContentFreshness.swift:ContentFreshness`): `nonisolated struct: Equatable, Sendable`;
  `init(staleAfter: TimeInterval, retryAfterFailure: TimeInterval)`, `static let standard` (from
  `AppConfig.Lists.staleAfter` and `retryAfterFailure`); `loadFailed: Bool`, `hasLoaded: Bool` (the instant itself is private);
  `mutating recordSuccess(at:version:userID:position: Coordinate? = nil)`, `recordFailure(at:version:userID:)`,
  `acknowledge(version:)`, `reset()`; `isWaitingToRetry(now:version:userID:) -> Bool`,
  `decision(now:version:userID:position: = nil) -> LoadDecision` (the one `switch` of `StoreLoader` and of the two list view models, which pass the position their request carries), `stalenessReason(now:version:userID:position:) -> String?`,
  `positionReason(for:) -> String?`. Nested `LoadDecision`: `.waitAfterFailure`, `.fresh`, `.stale(reason: String)`.
- `ChangeTracker` (`lily/Core/Changes/ChangeTracker.swift:ChangeTracker`): `@Observable final class`;
  `private(set) var version = 0`; `recordChange()` increments it. One instance per kind of data, shared through `AppDependencies`.
- `ListState` (`lily/Core/Changes/ListState.swift:ListState`): `nonisolated enum` `.loading`, `.empty`, `.failed`,
  `.content`; `init(isInitialLoad: Bool, isEmpty: Bool, loadFailed: Bool)`.
- `StoreLoader` (`lily/Core/Changes/StoreLoader.swift:StoreLoader`): `@Observable final class`;
  `init(noun: String, category: LogCategory, identity: any IdentityProvider, errorCenter: ErrorCenter, logger: any Logging, now: @escaping () -> Date, version: @escaping () -> Int)`;
  `isLoading`, `loadFailed`, `hasLoaded`; `loadIfStale(fetch:apply:) async`, `reload(fetch:apply:) async`,
  `acknowledge(version:)`, `reset()`.
- Children: [Interfaces](./Interfaces/EGM.md), [Implementations](./Implementations/EGM.md).

## Invariants

- `ContentFreshness.stalenessReason` answers, in order: `"never loaded"` (or `"retry after failure"` when a load failed
  before any success), `"changed elsewhere"` when the version moved, `"caller changed"`, `"retry after failure"`,
  `"older than TTL"` once `staleAfter` has passed, then the position reason. `positionReason` is never a reason before
  the first load; it compares `Coordinate.coarse` values and says `"position became known"` or `"position changed"`
  (`ContentFreshness.swift:stalenessReason`, `positionReason(for:)`).
- `isWaitingToRetry` is true only while `loadFailed`, the failed attempt's version and caller are unchanged, and less
  than `retryAfterFailure` has passed; a change elsewhere or a new caller lifts the cooldown. `recordSuccess` clears the
  failure and stores the version and caller taken before the request, so a change mid-flight makes the answer stale
  (`ContentFreshness.swift:isWaitingToRetry`, `recordSuccess`).
- `ListState`: `.content` whenever not empty; else `.loading` during the initial load; else `.failed` when the load
  failed, else `.empty`. A failed reload keeps what is on screen (`ListState.swift:init(isInitialLoad:isEmpty:loadFailed:)`).
- `StoreLoader`: a guest (`identity.currentUserID == nil`) is asked nothing. `loadIfStale` switches on
  `freshness.decision`; `reload` always runs, keyed by user id in `SingleFlight` (the same user joins the flight, another
  user waits it out). An answer whose caller is no longer current is dropped (`IdentityProvider.isStillCaller`). If
  `version()` moved while the request was out, the answer is still applied and the load runs exactly once more inside the
  same flight, so `isLoading` stays true through the repeat. A cancellation is logged at debug and neither recorded nor
  reported; any other failure is recorded, logged at error under `category` and reported
  (`StoreLoader.swift:loadIfStale`, `reload`, `loadOnce`).

## Side Effects

- `ErrorCenter.report(_:)` on a failed, non-cancelled load; the `apply` closure runs on the main actor with the fetched
  value (`StoreLoader.swift:loadOnce`).
- Spawned work: `SingleFlight.run` (`lily/Core/Concurrency/SingleFlight.swift`) runs the fetch in its own task.
- Logging: `.cache` debug for the reuse, reload, not-retrying and version-moved decisions; `category` debug for a
  cancelled load and error for a failed one (`StoreLoader.swift`). `ChangeTracker` and `ContentFreshness` log nothing.
- Observable state: `ChangeTracker.version`; `StoreLoader.isLoading`, `loadFailed`, `hasLoaded`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Changes`).
