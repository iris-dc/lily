# Groups

Source: `lily/Features/Groups/`

## Overview

The Groups feature of iskra: communities a user founds, discovers, joins and runs, plus the two other things the
backend keeps as groups of another `kind`, direct conversations (`direct`) and tournament rooms (`tournament`). The
folder holds no source files of its own; its seven subfolders follow the project's feature-and-layer layout.
Protocols (`Interfaces`) separate callers from the `Remote*` and `Mock*` repositories (`Implementations`); `Models`
are `nonisolated` wire and rule types (`SportGroup`, `GroupDraft` validation, `GroupAccess` role rules); `State`
holds the caller's long-lived stores, with `MyGroupsStore` the one source of the caller's groups; `ViewModels` run the
screens and their writes (one `TRY_AGAIN` repeat, refetch on an unknown outcome, errors through
`GroupErrorReporter` in `Services` to the shared `ErrorCenter`); `Views` are the SwiftUI screens, sheets, rows and
the `groupDestinations` navigation modifier. All of it runs without a backend behind the mocks, and its unit suites
live under `lilyTests/Groups` (`./scripts/ci.sh unit`).

## Subdirectories & Boundaries

- Interfaces: [`./Interfaces/EGM.md`](./Interfaces/EGM.md) - the six protocols: `GroupRepository` (reads, membership
  and role writes, idempotent `create` on `GroupDraft.clientId`), `InviteRepository`, `MeRepository` (the account,
  the terms, and account deletion: the advisory plan preview plus the asynchronous-accepted delete),
  `ModerationRepository`, the class-bound `RoomActivityRecorder` the chat layer calls, and `GroupDraftEditing`
  (refining `DraftSubmitting`) so create and edit share one form.
- Models: [`./Models/EGM.md`](./Models/EGM.md) - twenty-seven `nonisolated` value types: `SportGroup` and its
  copy builders (`mineOrder`, `noting`, `dropping`), `GroupKind: WireNamedKind` with `unknown`, roster and membership
  types, the request bodies that omit optionals, `GroupDraft` validated against `AppConfig.Groups` (name 3...60,
  description 500), `GroupAccess` (who may join, leave, edit, delete, invite, remove, ban, report), `GroupDetailSection`,
  `GroupConfirmation`, navigation and report values, and the account-deletion wire pair (`DeletionPlan`,
  `DeletionSettle`).
- Implementations: [`./Implementations/EGM.md`](./Implementations/EGM.md) - `Remote*` repositories over
  `/api/groups`, `/api/groups/{id}/...`, `/api/me`, `/api/reports` and `/api/blocks` with per-route fallback errors
  and no retry of their own; `Mock*` repositories and `MockGroupFixtures` (six Berlin communities, Marta's
  conversation, tournament rooms) replaying Laurel's refusals and orders in memory.
- Services: [`./Services/EGM.md`](./Services/EGM.md) - `GroupErrorReporter`: wraps any error as `AppError`, reports
  it to `ErrorCenter`, and calls back on `.termsRequired` so the terms sheet is raised.
- State: [`./State/EGM.md`](./State/EGM.md) - `MyGroupsStore` (per-caller `groups-mine` snapshot, 60 s freshness
  with a 10 s retry hold, `mineOrder` kept on local edits and room messages, `ChangeTracker` bumps),
  `MeStore` (account and terms state) and `BlockListStore` (replace-never-merge block list), all `SessionObserver`s
  cleared on sign-out.
- ViewModels: [`./ViewModels/EGM.md`](./ViewModels/EGM.md) - eight `@Observable` view models: create and edit drafts,
  Discover (300 ms debounce, 40-character query cap, 1.5 s position head start, cursor paging, plain-browse snapshot),
  the detail's join/leave/delete with refetch on an unknown outcome, the loader behind an event badge, the roster's
  role-gated actions, the invite and report sheets.
- Views: [`./Views/EGM.md`](./Views/EGM.md) - the Discover screen, cards, carousel and tiles; the group detail with
  its access-driven action row, menu, segments and single confirmation dialog; the shared draft form and sheets; the
  invite and report sheets; rows; and `View.groupDestinations(dependencies:onTournamentChange:)`, which routes a
  conversation to the profile and a room to the tournament, never to `GroupDetailView`.
