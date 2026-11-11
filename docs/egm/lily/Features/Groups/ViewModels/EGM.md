# Groups ViewModels

Source: `lily/Features/Groups/ViewModels/`

## Overview

Eight `@Observable`, main-actor view models, one per screen or sheet of the Groups feature: creating and editing a
draft (`CreateGroupViewModel`, `EditGroupViewModel`, both `GroupDraftEditing`), browsing and searching public groups
with cursor paging, a debounce and a position head start (`DiscoverGroupsViewModel`), the group detail with join,
leave and delete (`GroupDetailViewModel`), a group loaded behind an event's badge (`GroupLoaderViewModel`), the roster
with role-gated admin actions (`MembersViewModel`), the invite sheet (`InvitePeopleViewModel`) and the report sheet
(`ReportViewModel`). They depend only on the protocols in [Interfaces](../Interfaces/EGM.md) and the stores in
[State](../State/EGM.md); writes go through `WriteGate`, `CreateFlow` or `LostRace.attemptTwice` (one `TRY_AGAIN`
repeat, cancellation silent), failures through the shared `ErrorCenter`, and membership
changes into `MyGroupsStore`, whose `add`/`replace`/`remove` bump the shared `ChangeTracker`. The screens that drive
them are in [Views](../Views/EGM.md).

## Interface

- `CreateGroupViewModel: GroupDraftEditing`: `draft`, `private(set) isSubmitting`, `private(set) createdGroup:
  SportGroup?`, `issues`, `canSubmit`, `isDone` (`createdGroup != nil`), `prepare() async`, `submit() async`, and
  `placeSuggestions(for:) async` (the geocoder's places biased to the draft's spot, else the position `prepare()`
  read — the wizard place page's seam; slice 3, 2026-11-11);
  `init(repository: any GroupRepository, identity: any IdentityProvider, store: MyGroupsStore,
  locationService: any LocationService, geocoder: any GeocodingService = MockGeocodingService(),
  errorCenter: ErrorCenter, logger: any Logging, tryAgainDelay: Duration =
  AppConfig.API.tryAgainDelay, onCreated: @escaping @MainActor (SportGroup) -> Void)`; owns a private
  `CreateFlow<SportGroup>` [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.init`].
- `EditGroupViewModel: GroupDraftEditing`: `draft`, `private(set) isSubmitting`, `private(set) updatedGroup`, `issues`,
  `hasChanges`, `canSubmit`, `isDone`, `submit() async` (no `prepare` override); `init(group:, repository:, errorCenter:,
  logger:, tryAgainDelay: Duration = AppConfig.API.tryAgainDelay, onChange: @escaping @MainActor (SportGroup) ->
  Void)`; owns a private `WriteGate` [`lily/Features/Groups/ViewModels/EditGroupViewModel.swift`:`EditGroupViewModel.init`].
- `DiscoverGroupsViewModel`: settable `query`, `typeFilter: EventType?`, `reportsSearchFailures` (default true; the
  ten injected dependencies are private);
  `private(set)` `groups`, `isLoading`, `isLoadingMore`, `hasSearched`, `searchFailed`, `userLocation: Coordinate?`;
  `@ObservationIgnored` `nextCursor`, `searchedUserID`, `searchedChangesVersion`, `searchedPosition`,
  `searchedScope: GroupScope?`; computed
  `isInitialLoad`, `nothingMatched`, `canLoadMore`, `effectiveQuery: String?`, `browsePosition: Coordinate?`; methods
  `loadIfStale()`, `loadIfStaleNearTheUser()`, `loadUserLocation()`, `search()` (pull-to-refresh calls it too), `loadMore()`,
  `cancel()`, `clear()`, `distanceText(for:) -> String?`; `init(changes: ChangeTracker, repository:, identity:,
  locationService:, errorCenter:, recorder: any InteractionRecorder, logger:, sleep: @escaping Sleep = systemSleep,
  now:, snapshots: any ListSnapshotStore = NoOpListSnapshotStore())`
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.search`].
- `GroupDetailViewModel`: `private(set) group`, `let context: GroupDetailContext`, `private(set) isBusy`,
  `private(set) isGone`; computed `access: GroupAccess`, `showsRoster`, `showsOpenChat`, `canReport`,
  `reportTarget`, `showsMenu`; methods `recordViewed()`, `join()`, `leave()`, `delete()`, `accept(_ updated:)`,
  `refreshFromStore()`; `init(group:, context:, repository:, identity:, store: MyGroupsStore, errorCenter:, recorder:,
  logger:, tryAgainDelay:, now:)`; private `Intent { join, leave, delete }` and `Refetch { fresh, gone, unavailable }`,
  and a private `AppError` extension (`isGroupConflict`, `leavesOutcomeUnknown`, `needsGroupRefresh`)
  [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel`].
- `GroupLoaderViewModel`: `enum State: Equatable { loading, loaded(SportGroup), notFound, failed }`; `let ref:
  EventGroupRef`, `private(set) state`; `loadIfNeeded()`, `load()`; `init(ref:, repository:, errorCenter:, logger:)`
  [`lily/Features/Groups/ViewModels/GroupLoaderViewModel.swift`:`GroupLoaderViewModel.State`].
- `InvitePeopleViewModel`: `enum Content { loading, failed, nobody, noMatches, people }`; `let target: InviteTarget`,
  `private(set)` `candidates`, `isLoading`, `loadFailed`, `sendingUserIDs: Set<String>`, settable `query`; computed
  `visible`, `content`, `showsSearch`; `isSending(_:)`, `load()`, `invite(_:)`; `init(target:, repository: any
  InviteRepository, errorCenter:, logger:, tryAgainDelay:)`; owns a `WriteGate`
  [`lily/Features/Groups/ViewModels/InvitePeopleViewModel.swift`:`InvitePeopleViewModel.init`].
- `MembersViewModel`: `enum MemberAction: CaseIterable { makeAdmin, removeAdmin, remove, ban }` with `title`,
  `isDestructive`, `confirmation(for:) -> GroupConfirmation?`; `private(set)` `group`, `members`, `bans`, `isLoading`,
  `isBusy`; computed `access`, `showsBans`; `isSelf(_:)`, `update(group:)`, `actions(for:) -> [MemberAction]`,
  `load()`, `perform(_:on:)`, `unban(_:)`; `init(group:, repository:, identity:, errorCenter:, logger:, tryAgainDelay:,
  onChange: @escaping @MainActor (SportGroup) -> Void)`; owns a `WriteGate`
  [`lily/Features/Groups/ViewModels/MembersViewModel.swift`:`MembersViewModel.MemberAction`].
- `ReportViewModel`: `let target: ReportTarget`, `let title`, settable `reason: ReportReason?` and `comment`,
  `private(set) isSubmitting`, `isSubmitted`; computed `trimmedComment`, `canSubmit`; `submit()`; `init(target:,
  title:, repository: any ModerationRepository, errorCenter:, logger:)`
  [`lily/Features/Groups/ViewModels/ReportViewModel.swift`:`ReportViewModel.init`].

## Invariants

- No `nonisolated` mark in the directory: every class is `@Observable final class` under the main-actor default, and
  the `onCreated`/`onChange` callbacks are `@MainActor`
  [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.onCreated`].
- Create: `canSubmit = !isSubmitting && draft.isValid`; the client-chosen `draft.clientId` goes with every attempt, and
  on `.network` or `.groupCreationFailed` the flow looks the group up under that id and counts it created only when
  `role == .owner` (`.groupNotFound` means it did not land); `prepare()` proposes the device position only while
  `draft.coordinate == nil`, re-checked after the await
  [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.prepare`].
- `CreateFlow` repeats one `TRY_AGAIN` on the create, and answers `.createIdReused` (the earlier create landed with other
  details) with `repository.update(id: clientId, draft)`, whose answer is the created group
  [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.submit`].
- Edit: `canSubmit = !isSubmitting && hasChanges && draft.isValid` with `hasChanges = draft != GroupDraft(editing:
  original)`; one `TRY_AGAIN` repeat after `AppConfig.API.tryAgainDelay` (400 ms); no refetch on an unknown outcome
  because repeating an update is harmless [`lily/Features/Groups/ViewModels/EditGroupViewModel.swift`:`EditGroupViewModel.submit`]
  [`lily/Config/AppConfig.swift`:`AppConfig.API.tryAgainDelay`].
- Discover search: a `query` change restarts the search after `AppConfig.Groups.searchDebounce` (300 ms), a
  `typeFilter` change at once, both cancelling the pending task; `effectiveQuery` is the trimmed query capped at
  `AppConfig.Groups.queryMaxLength` (40 UTF-16 units), `nil` when blank, with no minimum length
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.effectiveQuery`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.Groups.searchDebounce`].
- Discover position: `browsePosition = effectiveQuery == nil ? userLocation?.coarse : nil` (a name search is global);
  `loadIfStaleNearTheUser()` gives `loadUserLocation()` at most `AppConfig.Location.firstFixWait` (1.5 s) through
  `HeadStart.give` before `loadIfStale()`; after an answer, a `searchedPosition` that differs from `browsePosition`
  triggers one immediate re-search (never after a failure or cancellation)
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.loadIfStaleNearTheUser`]
  [`lily/Config/AppConfig.swift`:`AppConfig.Location.firstFixWait`].
- Discover states: `isInitialLoad = !hasSearched && groups.isEmpty && !searchFailed`; `nothingMatched = hasSearched &&
  groups.isEmpty && !isLoading`; `canLoadMore = nextCursor != nil && !isLoadingMore && !isLoading`; `isStale` is
  "never searched, or the caller, the `ChangeTracker` version, the browse position or the scope (query and type)
  changed" (no time threshold; `searchedScope` is stamped by an answer, so a search cancelled on the way out under a
  new query is run on the next appearance)
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.isInitialLoad`].
- Discover guards: `search()` bumps a `searchGeneration` and both the search and `loadMore` drop an answer of an older
  generation; cancellation never sets `searchFailed`; `loadMore` dedups by id and reuses the searched position and
  the searched scope (`searchedScope`, stamped by the answer the cursor came from, never what is typed now; without
  one it returns), while a change of query or type restarts the search and bumps the generation; `clear()` cancels, bumps the generation and resets the list and
  the searched marks but keeps `userLocation`, `query` and `typeFilter`
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.clear`].
- Discover snapshot: written only when the scope the page was fetched for was a plain browse (no query, no type;
  `isPlainBrowse(_ scope:)` judges the captured scope, never the field when the answer lands), keyed by
  `AppConfig.Lists.discoverGroupsSnapshot` (`"groups-discover"`) and the caller; a seeded snapshot leaves
  `hasSearched` false [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.snapshotKey`]
  [`lily/Config/AppConfig.swift`:`AppConfig.Lists.discoverGroupsSnapshot`].
- Detail writes: dropped while `isBusy` or for a guest; one `TRY_AGAIN` repeat through `LostRace.attemptTwice`; on a
  failure with `needsGroupRefresh` the group is refetched, and the failure is suppressed only when the outcome was
  unknown (`.groupActionFailed`, `.network`, or `.notAMember` on a leave) and the fresh group already shows the intent
  (joined, left or gone, deleted or gone) [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.landed`].
- Detail writes for a previous caller: the caller is read before the request, and an answer, a failure or a refetch
  landing after they signed out or changed is dropped (`isStillCaller`): nothing written to Mine, nothing refetched or
  shown, only the `.cache` debug line; a failure whose caller changes during its read-back has already logged its
  failure line before the second check drops it
  [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.update`,
  `GroupDetailViewModel.refetch`].
- A create answered for a previous caller is dropped before `store.add` and `onCreated`: no `createdGroup`, nothing
  in Mine, no navigation [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.submit`].
- Detail gating: `showsRoster = access.canSeeMembers(in:)`; `showsOpenChat = access.canChat && context == .standalone
  && AppConfig.FeatureFlags.chat`; `canReport = access.canReport(in:)`; `showsMenu = access.canChat || canReport`;
  `refreshFromStore()` replaces `group` only when the store's `(loadVersion, changesVersion)` moved and the store
  holds the group and it is not gone; `apply` writes to the store with `add` for a live membership or `replace` when
  the store holds the id; `recordViewed()` records once per instance
  [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.showsOpenChat`].
- Loader: `loadIfNeeded()` fetches only while `.loading`; `load()` keeps a loaded group on screen through a reload or
  a non-`groupNotFound` failure; `.groupNotFound` always gives `.notFound`
  [`lily/Features/Groups/ViewModels/GroupLoaderViewModel.swift`:`GroupLoaderViewModel.load`].
- Invite: `load()` is dropped while loading; `invite` is dropped for an unknown, already invited or in-flight
  candidate; `visible` filters by `localizedStandardContains` with no debounce; `content` is `.failed`/`.loading`
  before the first answer, `.nobody` without candidates, `.noMatches` when the filter empties them, else `.people`
  [`lily/Features/Groups/ViewModels/InvitePeopleViewModel.swift`:`InvitePeopleViewModel.content`].
- Members: `actions(for:)` is empty unless the caller is a member and the row is not the caller; `makeAdmin`/
  `removeAdmin` need `canChangeRoles` and a `.member`/`.admin` target; `remove` and `ban` follow `GroupAccess.canRemove`/
  `canBan`; `perform` re-checks the action is allowed; `load()` sends nothing unless `canSeeMembers`, and fetches bans
  only when `showsBans = access.canEdit`; one write at a time through `WriteGate`; `update(group:)` ignores another id
  [`lily/Features/Groups/ViewModels/MembersViewModel.swift`:`MembersViewModel.allows`].
- Report: `canSubmit = reason != nil && !isSubmitting && trimmedComment.wireLength <= AppConfig.Moderation.commentMaxLength`
  (500); nothing is retried [`lily/Features/Groups/ViewModels/ReportViewModel.swift`:`ReportViewModel.canSubmit`]
  [`lily/Config/AppConfig+Moderation.swift`:`AppConfig.Moderation.commentMaxLength`].

## Side Effects

- Repository calls: `create(draft)` (and `group(id: clientId)` on an unknown outcome, `update(id: clientId, draft)`
  on a reused id), `update(id:_:)`, `groups(in:
  .discover(query:type:), cursor:, near:)`, `join`/`leave`/`delete(id:)` and `group(id:)` for a refetch,
  `group(id: ref.id)`, `candidates(groupID:)`, `invite(groupID:userID:)`, `members(id:)`, `bans(id:)`,
  `setRole(id:userID:_:)`, `remove(id:userID:)`, `unban(id:userID:)`, `report(_:)`
  [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.update`]
  [`lily/Features/Groups/ViewModels/MembersViewModel.swift`:`MembersViewModel.ban`].
- Store writes: `store.add(group)` after a create; `store.add`/`replace` after a detail action and `store.remove(id:)`
  when the group is gone (each bumps the `ChangeTracker`); the `onCreated`/`onChange` callbacks after a create, an
  edit, a remove or a ban [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.apply`].
- Location: `locationService.currentLocation()` from `CreateGroupViewModel.prepare()` (which also keeps the
  position as the suggestion bias) and `DiscoverGroupsViewModel.loadUserLocation()`;
  `geocoder.suggestions(for:near:)` from `CreateGroupViewModel.placeSuggestions(for:)` (2026-11-11) [`lily/Features/Groups/ViewModels/CreateGroupViewModel.swift`:`CreateGroupViewModel.prepare`].
- Statistics: `recorder.record(.groupSearchPerformed(hasQuery:resultCount:at:))` after a Discover answer and
  `recorder.record(.groupViewed(group, at:))` from `recordViewed()`
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.performSearch`].
- Disk: `snapshots.load` in `DiscoverGroupsViewModel.init`, `snapshots.save` after a plain-browse answer
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.init`].
- Errors: `errorCenter.report(error)` for kept failures of create, edit, detail, invite, members
  and report; `errorCenter.report` directly for Discover (the first page when `reportsSearchFailures`, a paging
  failure always) and the loader
  [`lily/Features/Groups/ViewModels/GroupLoaderViewModel.swift`:`GroupLoaderViewModel.load`].
- Spawned work: the debounced search `Task` (sleeping `searchDebounce`), `HeadStart.give`'s timer, and the
  `tryAgainDelay` sleep inside `WriteGate`/`LostRace.attemptTwice`
  [`lily/Features/Groups/ViewModels/DiscoverGroupsViewModel.swift`:`DiscoverGroupsViewModel.restartSearch`].
- Logging, ids only: `.groups` info for a created, updated, joined, left or deleted group, a Discover answer, a sent
  invite, a role change, removal, ban or unban, a filed report; warning for a group conflict or a refresh that failed;
  error for other failures; `.location` debug for the proposed spot; `.cache` debug for a position that changed
  mid-search; invite and report lines go under the target's `logCategory`
  [`lily/Features/Groups/ViewModels/GroupDetailViewModel.swift`:`GroupDetailViewModel.logSuccess`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Groups`, for
  example `CreateGroupViewModelTests`, `EditGroupViewModelTests`, `DiscoverGroupsViewModelTests`,
  `DiscoverGroupsMidSearchTests`, `DiscoverGroupsStalenessTests`, `DiscoverGroupsSnapshotTests`,
  `GroupDetailViewModelTests`, `GroupDetailCallerTests`, `GroupDetailRefreshTests`, `GroupLoaderViewModelTests`, `InvitePeopleViewModelTests`,
  `MembersViewModelTests`, `MembersViewModelGroupTests`, `ReportViewModelTests`).
