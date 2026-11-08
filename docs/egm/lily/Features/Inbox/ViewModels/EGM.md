# Inbox ViewModels

Source: `lily/Features/Inbox/ViewModels/`

## Overview

`InboxViewModel` is the inbox screen's model: the store's items as timeline rows, Accept and Decline on an invite, the
event behind an event reminder, the tournament behind a match reminder and the group behind an ownership notice. It
holds no copy of the items; they live in
`InboxStore` ([State](../State/EGM.md)), which the realtime controller and the Chats row share.

## Interface

- `@Observable final class InboxViewModel` `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:InboxViewModel]`;
  `init(store: InboxStore, repository: any InboxRepository, opener: EventOpener, myGroups: MyGroupsStore, tournamentChanges: ChangeTracker, navigation: AppNavigation, errorCenter: ErrorCenter, logger: any Logging, tryAgainDelay: Duration = AppConfig.API.tryAgainDelay, now: @escaping () -> Date = { .now })`.
- State: `store`, `busyItemIDs: Set<String>` (answers in flight), `openingItemID: String?` (the reminder whose game
  is being fetched), `now`; derived `rows: [InboxTimelineRow]` (`InboxTimeline.rows(store.items)`), `hasOlder`,
  `isLoadingOlder`, `loadFailed`, `isInitialLoad` (`!store.hasLoaded && !store.loadFailed`), `newestID`;
  `isBusy(_ item: InboxItem) -> Bool`.
- Actions: `appear() async`, `refresh() async`, `loadOlder() async` (answers nothing; the store's Bool is dropped),
  `noteNewItems() async`,
  `accept(_:) async`, `decline(_:) async`, `openEvent(for:) async`, `openTournament(for:)`, `openGroup(for:) async`.
- Private: `answer(_:verb:wanting:_:)`, `noteLanded(_:of:)`, `inviteReadBack: LostAnswer<[InboxItem]>`,
  `restated(_:for:)`, `AppError.isInviteVerdict` (`inviteNotPending` or `inviteExpired`)
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:isInviteVerdict]`.

## Invariants

- `appear()` and `refresh()` load (if stale, or always) and then mark read; `noteNewItems()` marks a live arrival read
  while the screen is open `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:appear]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:refresh]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:noteNewItems]`.
- `isInitialLoad` waits on the store's first answer or failure, not on `isLoading`, so the empty state never shows for
  one commit before the spinner `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:isInitialLoad]`.
- One answer per invite at a time: `answer` returns at once while the item is in `busyItemIDs`; a `TRY_AGAIN` is
  repeated once through `LostRace.attemptTwice` after `tryAgainDelay` (400 ms by default)
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:answer]`, `[lily/Config/AppConfig.swift:AppConfig.API.tryAgainDelay]`.
- An outcome left unknown (`.network`, `.inviteActionFailed`) is read back through `LostAnswer` before any popup:
  `store.reload()` is the refetch (a failed reload throws `.inboxUnavailable` into the read-back), and the card's
  `inviteAnswer.status` equal to the wanted status means the tap went through: nothing is reported and an accept
  reloads Mine and, for a tournament invite, bumps `tournamentChanges` (the page names no group or tournament, so
  nothing opens); a card still pending is reported. A verdict
  on the invite (`inviteNotPending`, `inviteExpired`) is a stale card, not a fault: the same read-back runs
  (`isWorthAnotherLook`), then a warning and the report, so the card shows the invite as the backend has it; any other
  failure logs at error and is reported; a cancellation is silent
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:answer]`, `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:inviteReadBack]`.
- `membershipLimitReached` on a tournament invite is restated as `AppError.tournamentMembershipLimit`, since the inbox
  route answers the groups cap and the tournaments cap under one code
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:restated]`.
- Accept: the answered item replaces the held one; a group goes into Mine at once and its chat opens; a tournament
  bumps `tournamentChanges`, reloads Mine first when the caller has entered, then opens the tournament; an acceptance
  naming neither reloads Mine, opens nothing and shows no popup `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:accept]`.
- `openEvent(for:)` and `openGroup(for:)` run one at a time (`openingItemID`) and only for an item with their payload;
  `openTournament(for:)` needs a `matchReminder` and fetches nothing. `openGroup` finds the group in Mine (reloading it
  once when not yet held — the caller owns the group now, so Mine is where it surfaces) and opens it on Home; a group
  Mine never learns logs a warning and reports `AppError.groupNotFound`
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openEvent]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openTournament]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openGroup]`.
- Main-actor isolated by the target's default.

## Side Effects

- `repository.accept(itemID:)` and `repository.decline(itemID:)`; `store.loadIfStale()`, `store.reload()`,
  `store.loadOlder()`, `store.markRead()`, `store.replace(_:)` `[lily/Features/Inbox/ViewModels/InboxViewModel.swift]`.
- `myGroups.add(group)` and `myGroups.reload()` (an accept's, and `openGroup`'s for a group not yet held);
  `tournamentChanges.recordChange()` `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:accept]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openGroup]`.
- Navigation: `navigation.open(chat:)`, `navigation.open(tournament:)`, `navigation.open(group:)` (an ownership
  notice), `navigation.openInChat(_:)` (a match
  reminder's `TournamentDestination`); `opener.open(eventID:from:)` pushes the game or reports one that is gone
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:accept]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openEvent]`,
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:openTournament]`.
- `errorCenter.report(failure)` for every failed answer the read-back did not find landed
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift:answer]`.
- Logging under `.inbox`: info on an accept (group, or tournament with its entry), a decline, a reminder opening a
  game or a match, an ownership notice opening its group; warning on an acceptance into nothing this build knows, on a
  verdict and on an ownership notice naming a group Mine does not hold; error on other failures;
  the `LostAnswer` lines with `what` = "Invite <id> <verb>": warning "Invite <id> <verb> outcome unknown (<error>);
  reading back", info "Reading back after <error> on Invite <id> <verb>" and "Invite <id> <verb> landed despite
  <error>; nothing to report", warning "Could not read back after Invite <id> <verb>: <error>"
  `[lily/Features/Inbox/ViewModels/InboxViewModel.swift]`, `[lily/Core/Networking/LostAnswer.swift:LostAnswer]`.
- No disk, timers or tasks of its own (the views wrap its async methods in `Task`).

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Inbox/InboxViewModelTests.swift`, `InboxViewModelTournamentTests.swift`,
  `DeletionNoticeTests.swift`).
