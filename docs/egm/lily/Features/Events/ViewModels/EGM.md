# Events ViewModels

Source: `lily/Features/Events/ViewModels/`

## Overview

Four `@Observable` main-actor classes own the Events screens' state. `EventListViewModel` drives every list and map
of events for one `EventScope` (`upcoming`, `joined`, `group`): it starts from the snapshot the list left on disk,
loads through `EventRepository` under `ContentFreshness` and `ChangeTracker` rules, gives the position a head start
before Explore's first load and applies the on-device `EventFilter`; its filter and freshness logic sit in the
`+Filter` and `+Freshness` extension files. `EventDetailViewModel` owns the event on screen, its `Participation`,
the join/leave write and the roster. `CreateEventViewModel` and `EditEventViewModel` own a draft each and conform
to `EventDraftEditing` ([Interfaces](../Interfaces/EGM.md)) for the shared form. Models are described in
[Models](../Models/EGM.md).

## Interface

- `EventListViewModel` (`lily/Features/Events/ViewModels/EventListViewModel.swift`):
  `init(scope:repository:identity:locationService:changes:errorCenter:recorder:logger:now:sleep:currencyCode:
  initialFilter:filterStore:snapshots:)` with defaults `now = { .now }`, `sleep = systemSleep`,
  `initialFilter = EventFilter()`, `NoOpEventFilterStore()`, `NoOpListSnapshotStore()`. State: `private(set)`
  `events`, `filter`, `isLoading`, `userLocation`; observation-ignored `startedFromSnapshot`,
  `filterWhenPanelOpened`; `freshness: ContentFreshness`. Derived: `visibleEvents`. Methods:
  `updateFilter(_ change: (inout EventFilter) -> Void)`, `loadIfStale()`, `load()`, `loadIfStaleNearTheUser()`,
  `loadUserLocation()`, `refreshUserLocation()`, `replace(_:)`, `add(_:)`, `clear()`.
- `EventListViewModel+Filter.swift`: `isEverythingFilteredOut`, `awaitsAnswerForPosition`, `priceCurrencyCode`,
  `toggleType(_:)`, `clearFilter()`, `showEverything()`, `distanceText(for:) -> String?`, `filterPanelOpened()`,
  `filterPanelClosed()`, `presentationChanged(to:)`.
- `EventListViewModel+Freshness.swift`: `isInitialLoad`, `listState: ListState`, `screenState: EventListScreenState`
  (`EventListScreenState.resolve` over `isInitialLoad`, `loadFailed`, `events`, `isEverythingFilteredOut` and
  `awaitsAnswerForPosition`: what Explore's screen shows, read by `EventListView+Content`), `loadFailed`, `hasLoaded`,
  `requestPosition: Coordinate?`, `positionReason: String?`, `stalenessReason: String?`. The
  stored `recorder` and `now` are internal for these extensions; `logger` is private (no extension reads it).
- `EventDetailViewModel` (`lily/Features/Events/ViewModels/EventDetailViewModel.swift`):
  `init(event:repository:identity:errorCenter:recorder:logger:tryAgainDelay: = AppConfig.API.tryAgainDelay,
  now:pushOptIn: = NoPushOptIn(), onChange: @MainActor (SportEvent) -> Void)`. State: `event`, `isBusy`,
  `participants`, `isLoadingParticipants`. Derived: `participation: Participation`, `canEdit`, `showsParticipants`,
  `hostProfile: UserProfileDestination?`, `isSelf(_:)`. Methods: `loadParticipants()`, `recordViewed()`, `join()`,
  `leave()`, `accept(_:)`.
- `CreateEventViewModel` (`lily/Features/Events/ViewModels/CreateEventViewModel.swift`):
  `init(repository:identity:locationService:groups: MyGroupsStore, errorCenter:logger:now:
  currencyCode:pushOptIn:lockedGroup: EventGroupRef? = nil, tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
  onCreated: @MainActor (SportEvent) -> Void)`. State:
  `draft`, `isSubmitting`, `createdEvent`, `eligibleGroups`, `belongsToGroups`, `let lockedGroup`. Derived:
  `issues`, `canSubmit`, `isDone`, `earliestStart`, `capacityRange`, `showsGroupRow`, `explainsNoEligibleGroups`.
  Methods: `prepare()`, `submit()`. `extension CreateEventViewModel: EventDraftEditing {}`. Takes a
  `geocoder: any GeocodingService = MockGeocodingService()` behind a `PlaceResolver`: `submit()` first fills whichever
  half of the place is missing (a typed name is geocoded into the spot, so a "Gdansk" game lands near Gdansk; a bare
  pin is named after the spot, falling back to the coordinates as text, never blank); `AppError.placeNotFound` (a name
  the geocoder cannot place) is reported to the `ErrorCenter` before anything is sent and the draft stays.
- `EditEventViewModel` (`lily/Features/Events/ViewModels/EditEventViewModel.swift`):
  `init(event:repository:errorCenter:logger:tryAgainDelay:now:currencyCode:onChange:)`. State: `draft`,
  `isSubmitting`, `updatedEvent`; the private `originalDraft` is `EventDraft(editing: event, currencyCode:)` built
  once in `init`, and `draft` starts as its copy. Derived: `issues`, `hasChanges`, `canSubmit`, `isDone`,
  `earliestStart`, `capacityRange`, `lockedGroup` (the original's group), `showsGroupRow`. Method: `submit()`, which
  resolves the place through the same `PlaceResolver` inside its gate (an edit can clear the name), so a failed
  geocode reaches the popup through the gate's report.
  `extension EditEventViewModel: EventDraftEditing {}`.

## Invariants

- Snapshot first (`EventListViewModel.init`): `events` starts from
  `snapshots.load([SportEvent].self, for: ListSnapshotKey(list: scope.snapshotList, userID:))`;
  `startedFromSnapshot = snapshot != nil`; `freshness` still reads "never loaded".
- `isInitialLoad = !startedFromSnapshot && !freshness.hasLoaded && !loadFailed` (`+Freshness`): a list that began
  from a snapshot, even an empty one, never shows the initial spinner.
- `keep(_:for:)` is the only writer of `events` that also saves its snapshot (`init` seeds `events` from the
  snapshot and `clear()` empties it without writing one): an answer is kept under the caller it was
  requested for, a local change (`replace`, `add`) under `identity.currentUserID`. In `performLoad` a signed-in
  caller's answer landing after they signed out is dropped; a guest's answer is kept.
- `load()`: dropped while `isLoading`; captures `loadGeneration` and, when `clear()` bumped it meanwhile, returns
  without touching `isLoading` or reloading; a success that left a `stalenessReason` (a change, sign-in or position
  landing mid-flight) reloads once at once.
- `loadIfStale()`: one `switch` on `freshness.decision(now:version:userID:position: requestPosition)`:
  `.waitAfterFailure` (`AppConfig.Lists.retryAfterFailure` = 10 s after a failure) and `.fresh` (within
  `AppConfig.Lists.staleAfter` = 60 s, same `changes.version`, same caller, same position) log and skip, `.stale(reason)`
  logs the reason and loads.
- Position: `requestPosition` is `userLocation` for `.upcoming` only. `loadIfStaleNearTheUser()` runs
  `HeadStart.give(AppConfig.Location.firstFixWait (1.5 s), sleep:, to: loadUserLocation, then: loadIfStale)` so
  the first answer is the one for the position. `loadUserLocation()` keeps the last fix on a miss and reloads when
  `positionReason != nil && !isLoading`; `refreshUserLocation()` first calls `locationService.forgetMissingFix()`.
- `awaitsAnswerForPosition = requestPosition != nil && !loadFailed && (!hasLoaded || positionReason != nil)`.
- `replace(_:)`: Explore updates the row in place and never takes a game it does not hold; `.joined` and `.group`
  re-insert by `startsAt` when `listsByStart` (`participates` / the same group id) or drop the row. `add(_:)`: no-op
  for an id already held; Explore inserts an `isListed` game at index 0; start-order lists insert by start when
  `listsByStart`. Both then `changes.recordChange()` and `freshness.acknowledge(version:)`.
- `clear()`: `loadGeneration += 1`, `isLoading = false`, `events = []`, `startedFromSnapshot = false`,
  `freshness.reset()`; no snapshot is written.
- `updateFilter` is the one way views change `filter`, saving through `filterStore` every time;
  `filterPanelClosed()` records `.filterApplied` only when the filter differs from when the panel opened.
- Detail write (`EventDetailViewModel.update`, `@discardableResult ... -> Bool`): one change at a time (`isBusy`,
  held exactly while the write settles); the write runs through
  `WriteGate.run(_:settling:_:)` with `what` = "<action> for event <id>" (one `TRY_AGAIN` repeated after
  `tryAgainDelay`, a cancellation silent, a 409 in `isParticipationConflict` (`.eventFull`, `.alreadyJoined`,
  `.notAParticipant`, `.hostCannotLeave`, `.tryAgain`) logged at warning, anything else at error, the failure
  reported unless the read-back found it landed); on success `apply` (→ `onChange`), log, `loadParticipants()`; it
  answers whether the change landed, and `join()` runs `pushOptIn.offerReminders()` after a landed update returned, so
  the offer never holds `isBusy` and a leave started during the prompt owns the flag to its own end.
- Detail read-back (`LostAnswer<SportEvent>`, `eventReadBack`): `.participationFailed` and `.network` leave the
  outcome unknown, every `isParticipationConflict` refusal is worth another look; `repository.event(id:)` is applied
  before the popup and the roster reloads after every fresh event; an unknown outcome whose fresh event shows
  `participates == wantsToParticipate` reports nothing.
- `loadParticipants()` is a no-op for guests (`showsParticipants = identity.currentUserID != nil`);
  `recordViewed()` records once per instance; `canEdit = participation == .hosting`; `hostProfile` is `nil` for a
  guest, an unknown host or the caller themselves.
- `canSubmit`: create `!isSubmitting && issues.isEmpty`; edit also `hasChanges` (`draft != originalDraft`, so a
  Region change while the sheet is up reads an untouched draft as unchanged). `submit()` guards on it and drops a call
  in flight. The create's default start is `Calendar.current.nextFullHour(after: now() + defaultStartOffset)`, and its
  `CreateFlow` judges `.network` and `.eventCreationFailed` as the outcomes left unknown (an inline closure, like the
  group and tournament forms).
- Create runs through `CreateFlow<SportEvent>` keyed on `draft.clientId`: one `TRY_AGAIN` is repeated; after
  `.network` or `.eventCreationFailed` it looks the event up by that id and claims it when
  `hostUserId == identity.currentUserID`; after `.createIdReused` it sends the draft as `repository.update(id:
  clientId, draft)` and the answer is the created event; the update carries no group, so `accept(_:)` logs a
  warning when the answer's group differs from the draft's.
  The default start is `AppConfig.Events.Creation.defaultStartOffset` (24 h) ahead, rounded to the next full hour;
  `draft.group` is stamped with `lockedGroup`.
- `CreateEventViewModel.prepare()`: `eligibleGroups = groups.eligibleForEvents.map(\.ref)`, `belongsToGroups =
  !groups.communities.isEmpty`; the user's position is proposed as the spot only while `draft.coordinate == nil`,
  re-checked after the await.
- Edit uses `EventDraft.Rules.editing(participantCount:)`; the update runs through `WriteGate.run`, which repeats one
  `TRY_AGAIN`, keeps a cancelled sheet quiet and reports failures; the group cannot change.

## Side Effects

- Repository calls: `events(in:near:)`, `participants(eventId:)`, `join`, `leave`, `event(id:)` (refetch and
  `CreateFlow` lookup), `create(_:)`, `update(id:_:)`.
- Disk: `ListSnapshotStore.load` in `init` and `save` in `keep`; `EventFilterStore.save` on every filter change.
- `ChangeTracker.recordChange()` after `replace` and `add`; `ContentFreshness.recordSuccess` / `recordFailure` /
  `acknowledge` / `reset` bookkeeping.
- Location: `locationService.currentLocation()` (list and create), `forgetMissingFix()` on foregrounding.
- `ErrorCenter.report` on a failed load, a failed roster load, a participation failure not shown to have landed, and
  through `CreateFlow` and `WriteGate`.
- `InteractionRecorder.record`: `.filterApplied`, `.presentationChanged`, `.viewed`.
- Logging: `.events` (loads, join and leave outcomes, "Capacity reached", create, update, "stays in group" after a
  reused id), `.cache` (fresh, stale,
  retry and dropped-answer decisions, sibling invalidation), `.location` (fix available, changed, none).
- Callbacks: `onChange(SportEvent)` (detail, edit), `onCreated(SportEvent)` (create);
  `pushOptIn.offerReminders()` after a join or a create.
- Sleep: `HeadStart` on the injected `Sleep` for at most `firstFixWait`; `LostRace` and `WriteGate` wait
  `tryAgainDelay` (400 ms) before their one retry.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/EventListViewModelTests.swift`,
  `EventListSnapshotTests.swift`, `EventListStalenessTests.swift`, `EventListPositionFirstTests.swift`,
  `EventListPositionStalenessTests.swift`, `EventListAddTests.swift`, `EventListChangeTests.swift`,
  `EventListFilteringTests.swift`, `EventDetailViewModelTests.swift`, `EventDetailCapacityTests.swift`,
  `EventDetailParticipantsTests.swift`, `EventDetailEditTests.swift`, `EventDetailPushOptInTests.swift`,
  `CreateEventViewModelTests.swift`, `CreateEventGroupTests.swift`, `CreateEventPushOptInTests.swift`,
  `EditEventViewModelTests.swift`).
