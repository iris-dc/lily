# Tournaments: ViewModels

Source: `lily/Features/Tournaments/ViewModels/`

## Overview

The four `@Observable final class` view models of the Tournaments feature, all without an isolation annotation and so
main-actor isolated under the app target's default. `TournamentListViewModel` drives every list (`.upcoming` for the
Explore carousel and Discover, `.mine` for Home, `.group(id)` for a group's segment) with snapshot seeding,
`ContentFreshness` rules, `ChangeTracker` bumps and a head start for the position. `TournamentDetailViewModel` (with
its `+Actions`, `+Entries` and `+Matches` files) owns the detail screen: it fetches by `destination.id`, draws the
opener's preview until the fetch answers, derives permissions, and reads the detail back through `LostAnswer` after an
entry or match write whose outcome is unknown (entries also after the refusals a stale detail earns). `CreateTournamentViewModel` and `EditTournamentViewModel` are the `TournamentDraftEditing`
conformers ([`../Interfaces/EGM.md`](../Interfaces/EGM.md)) behind the draft sheets. Every dependency is a protocol
(`TournamentRepository`, `IdentityProvider`, `LocationService`, `ListSnapshotStore`, `Logging`, `PushOptIn`,
`GroupRepository`, `InteractionRecorder`) or a shared store (`ChangeTracker`, `ErrorCenter`, `GroupErrorReporter`,
`MyGroupsStore`, `AppNavigation`); the models they manipulate are in [`../Models/EGM.md`](../Models/EGM.md). None
of the seven files sends invites; the invite sheet is the shared one built by `AppDependencies`.

## Interface

- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.init]`:
  `init(scope: TournamentScope, repository: any TournamentRepository, identity: any IdentityProvider, locationService:
  any LocationService, changes: ChangeTracker, errorCenter: ErrorCenter, logger: any Logging, now: @escaping () -> Date =
  { .now }, sleep: @escaping Sleep = systemSleep, snapshots: any ListSnapshotStore = NoOpListSnapshotStore())`; seeds
  `tournaments` from `snapshots.load(...)` under `ListSnapshotKey(list: scope.snapshotList, userID:)`.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.tournaments]`: state
  `scope`, `private(set) tournaments`, `private(set) isLoading`, `private(set) userLocation: Coordinate?`,
  `typeFilter: EventType?`, `reportsFailures` (false for the Explore carousel); computed `isInitialLoad`,
  `listState: ListState`, `loadFailed`, `visibleTournaments` (filtered by `typeFilter`); no `hasLoaded`, the screens
  judge by `isInitialLoad`, `listState` and `loadFailed`.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.loadIfStale]`:
  `loadIfStale() async`, `load() async` (pull to refresh), `loadIfStaleNearTheUser() async` (position head start
  then `loadIfStale`), `loadUserLocation() async`, `replace(_ tournament:)`, `add(_ tournament:)`, `clear()`,
  `distanceText(for:) -> String?`.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.init]`:
  `init(destination: TournamentDestination, repository:, groupRepository: any GroupRepository, myGroups:
  MyGroupsStore, identity:, navigation: AppNavigation, changes: ChangeTracker, reporter: GroupErrorReporter,
  recorder: any InteractionRecorder, logger:, tryAgainDelay: Duration = AppConfig.API.tryAgainDelay, now: @escaping
  () -> Date = { .now }, pushOptIn: any PushOptIn = NoPushOptIn(), onChange: @MainActor (Tournament) -> Void)`; builds a
  `WriteGate(category: .tournaments, ..., isExpected: { $0.isTournamentRefusal })`.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.State]`:
  `enum State: Equatable { loading, previewing(Tournament), loaded(TournamentDetail), notFound, failed }`; state
  `destination`, `private(set) state`, `previewLoadFailed`, `isBusy`, `isGone`, `linkedMatchToShow: String?`;
  computed `detail`, `preview`, `tournament`, `shownDetail`, `isPreviewing`, `name`, `role: TournamentRole`,
  `participation: TournamentParticipation`, `permissions: TournamentPermissions` (with `chatEnabled:
  AppConfig.FeatureFlags.chat`), `reportTarget`, `winnerName`, `isSelf(_:)`.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.loadIfNeeded]`:
  `loadIfNeeded() async`, `@discardableResult load(reportingFailures: Bool = true) async -> Bool` (`false` only
  for a cancellation while still the current load), `accept(_ detail:)`,
  `consumeLinkedMatch()`, and the shared write frame
  `@discardableResult perform(_ action: String, _ work: () async throws -> Void) async -> Bool` with its
  `perform(_ action: String, settling: (any Error) async -> Bool, _ work: () async throws -> Void) async -> Bool`
  overload; `extension AppError { var isTournamentRefusal: Bool; var leavesTournamentWriteOutcomeUnknown: Bool }` is
  internal, the second shared by the `+Entries` and `+Matches` files; `repository`, `myGroups`, `identity`, `logger`
  and `pushOptIn` are internal `let`s for the `+Actions`, `+Entries` and `+Matches` files, `groupRepository` and
  `navigation` for the `+Actions` file; `reporter`, `now`, `onChange`, `recorder`, `gate` and `changes` are private.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Actions.swift:TournamentDetailViewModel.openChat]`:
  `openChat() async`, `cancel() async`, the menu actions that write no entry and no match.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Entries.swift:TournamentDetailViewModel.join]`:
  `canJoin(_ entry:) -> Bool`, `join() async`, `@discardableResult createTeam(named:onEntered: () -> Void = {}) async -> Bool`,
  `joinTeam(_ entry:) async`, `leave() async`, `removeEntry(_ entry:) async`.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Matches.swift:TournamentDetailViewModel.report]`:
  `hasMatches`, `actions(for:) -> MatchActions`, `entryName(_:) -> String`, `start() async`, and the
  `@discardableResult ... async -> Bool` writes `report(_:scoreA:scoreB:)`, `confirm(_:)`, `dispute(_:)`,
  `walkover(_:winnerEntryID:)`, `schedule(_:_:)`.
- `[lily/Features/Tournaments/ViewModels/CreateTournamentViewModel.swift:CreateTournamentViewModel.init]`:
  `init(repository:, identity:, locationService:, groups: MyGroupsStore, reporter:, logger:, now: @escaping () -> Date =
  { .now }, pushOptIn:, lockedGroup: EventGroupRef? = nil, tryAgainDelay: Duration =
  AppConfig.API.tryAgainDelay, onCreated: @MainActor (TournamentDetail) -> Void)`; builds a `CreateFlow<TournamentDetail>` keyed on the draft's client id. State `draft`, `isSubmitting`,
  `created`, `eligibleGroups`, `belongsToGroups`, `lockedGroup`; the `TournamentDraftEditing` members
  (`issues`, `canSubmit`, `isDone`, `earliestStart`, `proposedDeadline()`, `entriesRange`, `isLocked = false`,
  `allowsStructureChanges = true`, `showsGroupRow`, `explainsNoEligibleGroups`); `prepare() async`, `submit() async`.
- `[lily/Features/Tournaments/ViewModels/EditTournamentViewModel.swift:EditTournamentViewModel.init]`:
  `init(tournament: Tournament, repository:, reporter:, logger:, tryAgainDelay:, now:, onChange: @MainActor
  (TournamentDetail) -> Void)`; `draft = TournamentDraft(editing:)`, `rules = .editing(entryCount:, isLocked:
  status != .registration)`, a `WriteGate` without `isExpected`. State `draft`, `isSubmitting`, `updated`; computed
  `hasChanges`, `canSubmit`, `isDone`, `isLocked = !rules.judgesSchedule`, `allowsStructureChanges = false`,
  `lockedGroup = original.group`, `showsGroupRow`; `submit() async`.

## Invariants

- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.init]`: a snapshot is
  a hint, never an answer: `freshness` stays `ContentFreshness.standard` after seeding, so the first `loadIfStale`
  still requests; `isInitialLoad` is `!startedFromSnapshot && !hasLoaded && !loadFailed`, false when any snapshot
  (even an empty one) was found.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.keep]`: every list
  write goes through `keep(_:for:)`, which sets `tournaments` and saves the snapshot in one step; a load saves under
  the caller captured before the request, `replace`/`add` under the current caller; `clear()` and the guest `.mine`
  branch save nothing.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.loadIfStale]`: a
  guest's `.mine` is answered empty with no request; otherwise one `switch` on
  `freshness.decision(now:version:userID:position: requestPosition)`: `.waitAfterFailure` (`AppConfig.Lists.retryAfterFailure`)
  and `.fresh` skip, `.stale(reason)` (never loaded, changed elsewhere, caller changed, older than
  `AppConfig.Lists.staleAfter`, or a position arrived or moved) loads.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.load]`: single flight
  (`guard !isLoading`); the load generation is captured first and a `clear()` meanwhile disowns the answer without
  touching `isLoading`; after a successful answer a non-nil `stalenessReason` triggers a further `load()`, bounded
  because only a landing between request and answer makes a fresh answer stale;
  a signed-in caller's answer is dropped when `identity.currentUserID` changed in flight; cancellations are swallowed;
  other failures record a failure, log at error and reach `errorCenter` only when `reportsFailures`.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.loadIfStaleNearTheUser]`:
  `HeadStart.give(AppConfig.Location.firstFixWait, ...)` lets `loadUserLocation` run up to 1.5 s before
  `loadIfStale`; only `.upcoming` sends the position, and a fix arriving later reloads once when no load is in flight.
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.belongs]`: scope
  membership mirrors the backend listing: `.upcoming` needs `isListed`, `.mine` needs organiser or entrant,
  `.group(id)` needs that group and not cancelled; `replace` updates, removes or inserts by start accordingly and
  `add` ignores a known id; both call `changes.recordChange()` then acknowledge the new version, so siblings reload
  and this list does not.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.load]`: the
  initial state is `.previewing(destination.preview)` or `.loading`; every load, `accept` and `markGone` bumps
  `loadGeneration`, and an answer from an older generation is dropped. `loadIfNeeded` runs only when `!isGone` and
  (`detail == nil` or `acknowledgedVersion != changes.version`); it acknowledges the version before loading and
  restores the previous acknowledgement when `load()` answers `false` with the acknowledgement still its own, so a
  reload cancelled by a disappearance is asked again on return while a reported failure stays acknowledged.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.reportLoadFailure]`:
  a failed reload never blanks a loaded detail: with a preview `previewLoadFailed = true`, with nothing `state =
  .failed`, with a detail nothing changes; the error is reported in all three cases. `.tournamentNotFound` before
  any load is `.notFound`; after a load it sets `isGone`, removes the room from `myGroups` and records a change.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.accept]`: `accept`
  shows the detail, hands `detail.tournament` to `onChange` and acknowledges the tracker's version without recording
  a change; `noteRefreshFailure` (a failed refetch after a landed entry write) records a change and shows no popup.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.perform]`: one
  action at a time, signed-in only (`guard !isBusy, identity.currentUserID != nil`); the `WriteGate` repeats a
  `TRY_AGAIN` once after `AppConfig.API.tryAgainDelay`, stays quiet on cancellation, asks `settling` first (a landed
  write answers `true` with no popup), then logs refusals at warning and faults at error, and reports every other
  non-cancelled failure through `reporter` (so `.termsRequired` raises the terms sheet).
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:AppError.isTournamentRefusal]`: the expected
  refusals are `.tournamentNotFound`, `.registrationClosed`, `.tournamentFull`, `.alreadyEntered`, `.teamFull`,
  `.entryNotFound`, `.notOrganizer`, `.tournamentLocked`, `.notEnoughEntries`, `.notInMatch`, `.matchNotReady`,
  `.matchNotFound`, `.drawNotAllowed`, `.tournamentLimit`, `.tournamentMembershipLimit`, `.tryAgain`,
  `.termsRequired`; they are shown, never swallowed.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Entries.swift:TournamentDetailViewModel.settleEntry]`:
  entry writes answer an entry only, so `join`, `createTeam`, `joinTeam`, `leave` and `removeEntry` refetch with
  `load(reportingFailures: false)` after an answer; a `.network` or `.tournamentActionFailed`
  (`leavesTournamentWriteOutcomeUnknown`), and every `isTournamentRefusal` except `.termsRequired` and `.tryAgain`, read the
  detail back through `LostAnswer<TournamentDetail>` (`repository.tournament(id:)` applied through `accept`); a lost
  answer whose fresh detail shows the intent (`hasEntered`, `!hasEntered`, the entry gone) counts as landed and reports
  nothing. The first four reload Mine when the write landed, because the backend moves the caller's room in the same
  transaction; `pushOptIn.offerReminders()` runs only after a landed enter, outside the gate; `createTeam` runs
  `onEntered` first, before the Mine reload and the offer, and answers whether the team exists. `leave` needs `myEntryId` and a caller, and drops the room from `myGroups` only for a
  non-organiser. `canJoin` needs `permissions.canJoinTeams`, a registered entry and a free seat; a full tournament is
  no bar.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Matches.swift:TournamentDetailViewModel.writeMatch]`:
  only `.network` and `.tournamentActionFailed` (`leavesTournamentWriteOutcomeUnknown`, the same rule as the entry
  writes') leave a match write's outcome unknown and trigger `readBack`; a refusal propagates as the backend's word. `readBack` refetches the detail and asks `MatchWrite.landed(on:callerID:)`:
  a landed write returns the fresh detail and reports nothing; a write that did not land still accepts the fresh
  detail before the error goes on; a failed read leaves the screen untouched.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Matches.swift:TournamentDetailViewModel.schedule]`:
  `schedule` goes through `writeMatch` like every match write: the answered `TournamentMatch` takes its place in the
  loaded detail (`replacing(match:)`), and without a loaded detail the tournament is fetched back instead (a read
  that 404s or fails reports like every sibling write); the "scheduled" / "schedule cleared" info line is logged
  once after the write landed, directly or through the read-back.
  Every other match write and `start` replace the whole detail through `accept`.
- `[lily/Features/Tournaments/ViewModels/CreateTournamentViewModel.swift:CreateTournamentViewModel.submit]`:
  `canSubmit = !isSubmitting && issues.isEmpty` under `Rules.creation`; `isSubmitting` guards a second tap. The
  default start is `AppConfig.Tournaments.defaultStartOffset` ahead rounded to the next full hour; the position is
  proposed only while `draft.coordinate == nil` (re-checked after the await). `CreateFlow` repeats one `TRY_AGAIN`,
  treats `.network` and `.tournamentCreationFailed` as unknown, looks the draft's `clientId` up and counts the create
  as landed only when the caller organises it, and answers `.createIdReused` with `repository.update(id: clientId,
  draft)`; every kept failure is reported. `accept` compares the answered tournament's `format`, `teamSize`,
  `visibility` (only for a draft without a group, since `CreateTournamentPayload` leaves it out with a `groupId`) and
  `group?.id` with the draft and logs one warning per field that differs, because `UpdateTournamentPayload` carries none
  of them: the first tap's structure stands and the sheet still closes on the answer.
- `[lily/Features/Tournaments/ViewModels/EditTournamentViewModel.swift:EditTournamentViewModel.submit]`: `canSubmit =
  !isSubmitting && hasChanges && issues.isEmpty` with `hasChanges = draft != TournamentDraft(editing: original)`
  under `Rules.editing`; after the start the form is locked and structure never changes; the gate repeats one
  `TRY_AGAIN` and reports other failures.

## Side Effects

- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.performLoad]`:
  `repository.tournaments(in:near:)`; `snapshots.load` in `init` and `snapshots.save` on every answer, `replace` and
  `add`; `locationService.currentLocation()` per appearance; a `HeadStart` task group sleeping
  `AppConfig.Location.firstFixWait`; `changes.recordChange()` after own changes; `errorCenter.report` on failure
  when `reportsFailures`. Logs: `.tournaments` info on a load ("Loaded N tournaments for scope ...; with position:
  ..."), error on failure, debug on cancellation; `.cache` debug for every skip, reload and invalidation reason.
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel.swift:TournamentDetailViewModel.load]`:
  `repository.tournament(id:)`, also as the read-back after a lost or refused entry write (one per failure);
  `recorder.record(.tournamentViewed(...))` once per instance; `myGroups.remove(id:)`
  and `changes.recordChange()` when the tournament is gone; `onChange(detail.tournament)` from `accept`;
  `reporter.report` on a reported failure. Logs under `.tournaments`: info on a 404, error on a failed load,
  warning on a failed refetch after a write, and `LostAnswer`'s "<action> for tournament <id> outcome unknown",
  "Reading back after", "landed despite", "Could not read back after".
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Actions.swift:TournamentDetailViewModel.openChat]`:
  `groupRepository.group(id:)`, `myGroups.add(room)` when a member, and the navigation mutation
  `navigation.open(chat: room)`; `cancel` calls `repository.cancel(id:)` and logs "Tournament ... cancelled".
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Entries.swift:TournamentDetailViewModel.enter]`:
  `repository.join`, `joinTeam`, `leave`, `removeEntry`; `myGroups.reload()`; `pushOptIn.offerReminders()`; info
  logs "joined as entry", "left (entry ...)", "entry ... removed".
- `[lily/Features/Tournaments/ViewModels/TournamentDetailViewModel+Matches.swift:TournamentDetailViewModel.report]`:
  `repository.start`, `report`, `confirm`, `dispute`, `walkover`, `schedule`, plus one extra
  `repository.tournament(id:)` read-back after an unknown outcome; info logs per match ("Match ... of tournament
  ...: result/confirmed/disputed/walkover/scheduled/schedule cleared"), "Tournament ... completed" once, and a
  warning when the read-back fails.
- `[lily/Features/Tournaments/ViewModels/CreateTournamentViewModel.swift:CreateTournamentViewModel.submit]`:
  `repository.create(draft)` through `CreateFlow` with a `repository.tournament(id: clientId)` lookup after an unknown
  outcome and `repository.update(id: clientId, draft)` after `.createIdReused`; `locationService.currentLocation()`
  from `prepare`; `onCreated(detail)` then `pushOptIn.offerReminders()`;
  `reporter.report` on a kept failure. Logs through `CreateFlow` (`lily/Core/Networking/CreateFlow.swift`):
  `.tournaments` info "Tournament created ...", error "Create failed ..."; the view model's own logs are `.location`
  debug on the proposed position and `.tournaments` warning "Tournament <id> keeps its <field>; the draft named
  another" per structure field a reused-id update could not carry (`noteStructureKept`).
- `[lily/Features/Tournaments/ViewModels/EditTournamentViewModel.swift:EditTournamentViewModel.submit]`:
  `repository.update(id:_:)` through the gate; `onChange(detail)`; info log "Tournament ... updated (...)".
- `[lily/Features/Tournaments/ViewModels/TournamentListViewModel.swift:TournamentListViewModel.init]`: the injected
  `ListSnapshotStore` is the only disk access in the directory; no UserDefaults, timers or notifications.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`,
  `CreateTournamentOutcomeTests` included).
