# Shell: Services

Source: `lily/Features/Shell/Services/`

## Overview

Two app-lifetime services behind the shell. `ShellLists` owns the Home and Explore list view models so a tab never opens
empty (each starts from its disk snapshot) and clears them when the session ends. `ShellSync` runs the per-user work
once per scene phase and user in a load-bearing order: the session check against the pool, the account, the realtime
connection, the caller's groups, the inbox, the block list, then the push offer and registration, with Explore's loads
alongside. Both classes are main-actor isolated by the app target's default and depend on collaborators injected by
`AppDependencies`.

Files: `lily/Features/Shell/Services/ShellLists.swift`, `lily/Features/Shell/Services/ShellSync.swift`.

## Interface

- `[ShellLists.swift:ShellLists]`: `final class ShellLists: SessionObserver` (the protocol is declared in
  `lily/Core/Auth/Interfaces/SessionObserver.swift` with `sessionDidEnd()` required and `sessionDidRestore()`
  defaulted). Stored: `let homeEvents: EventListViewModel`, `let homeTournaments: TournamentListViewModel`,
  `let exploreEvents: EventListViewModel`, `let discover: DiscoverGroupsViewModel`,
  `let exploreTournaments: TournamentListViewModel`.
- `[ShellLists.swift:ShellLists.init]`: `init(homeEvents:homeTournaments:exploreEvents:discover:exploreTournaments:)`
  stores the five view models.
- `[ShellLists.swift:ShellLists.loadExploreIfStale]`: `func loadExploreIfStale() async` runs Explore's three
  position-first loads concurrently.
- `[ShellLists.swift:ShellLists.sessionDidEnd]`: `func sessionDidEnd()` calls `clear()` on all five view models.
- `[ShellSync.swift:ShellSync]`: `final class ShellSync`; `init(session: SessionController, me: MeStore, realtime:
  RealtimeSessionController, myGroups: MyGroupsStore, inbox: InboxStore, blocks: BlockListStore, push: PushCoordinator,
  lists: ShellLists)`.
- `[ShellSync.swift:ShellSync.restore]`: `func restore() async` awaits `session.restore()` then `push.openPendingTap()`.
- `[ShellSync.swift:ShellSync.run]`: `func run(active: Bool, user: AuthUser?) async`, the per-phase sync chain.

## Invariants

- `[ShellLists.swift:ShellLists.loadExploreIfStale]`: `exploreEvents.loadIfStaleNearTheUser()`, the Discover load and
  the tournaments load run as three `async let` children and are all awaited; Discover loads only `if
  AppConfig.FeatureFlags.groups`, the tournaments only `if AppConfig.FeatureFlags.tournaments`.
- `[ShellLists.swift:ShellLists.sessionDidEnd]`: every list is cleared on session end so one account's lists never show
  for the next; the comment notes the snapshot store is registered after this observer and sweeps what clearing wrote.
- `[ShellSync.swift:ShellSync.run]`: order is fixed: `session.restore()`, then `async let explore`, `me.loadIfNeeded()`
  (active only), `realtime.setDesired(active:user:)`, `myGroups.loadIfStale()`, `inbox.loadIfStale()`,
  `blocks.loadIfNeeded()` (each active only), then `push.offerReminders()` and `push.sync()` (active only), then
  `await explore`. The file's comment gives the reasons: the account before the connection (the endpoint comes from
  `me`), the connection before Mine (a connection that opens reloads Mine), the inbox after Mine, the block list after
  the inbox.
- `[ShellSync.swift:ShellSync.run]`: `guard !Task.isCancelled else { return }` sits between every step and `guard
  !Task.isCancelled, active` before the push steps, so a cancelled run never applies a stale phase; the check before
  `setDesired` keeps a stale run from reopening a connection the background run closed. An early return also cancels
  the `explore` child.
- `[ShellSync.swift:ShellSync.run]`: an inactive run (`active == false`) only verifies the session and tells the realtime
  connection to close; every load is skipped.
- `[ShellSync.swift:ShellSync.loadExploreIfStale]`: `guard active, session.state != .signedOut else { return }`, read
  after `session.restore()`, so a signed-out visitor on the landing loads nothing and asks for no position.
- `[ShellSync.swift:ShellSync.run]`: every run first joins `session.restore()`, so nothing loads for a user the pool
  has not confirmed.

## Side Effects

- Network and state through collaborators, in `[ShellSync.swift:ShellSync.run]`: `session.restore()` (the Cognito
  check), `me.loadIfNeeded()`, `realtime.setDesired(active:user:)` (opens or closes the realtime connection),
  `myGroups.loadIfStale()`, `inbox.loadIfStale()`, `blocks.loadIfNeeded()`, `push.offerReminders()` (may show the
  notification permission prompt), `push.sync()` (device registration), and `lists.loadExploreIfStale()`.
- `[ShellSync.swift:ShellSync.restore]`: `push.openPendingTap()` may navigate to the screen a tapped notification
  named.
- `[ShellLists.swift:ShellLists.loadExploreIfStale]`: `loadIfStaleNearTheUser()` on the three Explore view models (each
  asks for the position and may hit the backend when its content is stale).
- `[ShellLists.swift:ShellLists.sessionDidEnd]`: mutates the five view models (`clear()`); any snapshot writes are theirs.
- No logging is done in these two files.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites are `lilyTests/Shell/ShellListsTests.swift`,
  `lilyTests/Shell/ShellSyncTests.swift` and `lilyTests/Shell/ShellSyncExploreTests.swift`).
